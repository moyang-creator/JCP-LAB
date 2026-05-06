// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title JCPExchangeV3
 * @author 您的 DeFi 实验室
 * @dev 具备 LP 凭证、双边兑换、手续费及实时监控功能的完整交易所合约
 */
contract JCPExchangeV3 is ERC20, Ownable, ReentrancyGuard {
    IERC20 public jcpToken;
    IERC20 public jcpusdToken;

    // 池子储备量（用于 AMM 数学计算）
    uint256 public jcpReserve;
    uint256 public jcpusdReserve;

    // 手续费乘数：997 代表 0.3% 手续费 (即 1 - 997/1000)
    uint256 public feeMultiplier = 997;

    // 事件记录：方便在 Sepolia 浏览器中追踪实验动态
    event Mint(address indexed sender, uint256 amountJCP, uint256 amountJCPUSD, uint256 lpTokens);
    event Burn(address indexed sender, uint256 amountJCP, uint256 amountJCPUSD, uint256 lpTokens);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool isJCPToUSD);

    // 构造函数：需要传入您之前部署的 JCP 和 JCPUSD 合约地址
    constructor(address _jcp, address _jcpusd) 
        ERC20("JCP Liquidity Provider", "JCP-LP") 
        Ownable(msg.sender) 
    {
        jcpToken = IERC20(_jcp);
        jcpusdToken = IERC20(_jcpusd);
    }

    // --- 1. 监控面板 (Dashboard) ---
    
    /**
     * @notice 一键获取池子核心数据
     * 返回：[JCP余额, JCPUSD余额, 已发出的LP总量, 1个JCP能换多少个USD(带18位精度)]
     */
    function getPoolStats() public view returns (
        uint256 reserveJCP, 
        uint256 reserveJCPUSD, 
        uint256 totalLP, 
        uint256 jcpPriceInUSD
    ) {
        reserveJCP = jcpReserve;
        reserveJCPUSD = jcpusdReserve;
        totalLP = totalSupply();
        // 价格 = (reserveJCPUSD / reserveJCP)，通过放大 1e18 处理浮点数
        jcpPriceInUSD = reserveJCP > 0 ? (reserveJCPUSD * 1e18) / reserveJCP : 0;
    }

    // --- 2. 流动性管理 (Add/Remove Liquidity) ---

    // 注入流动性：学生投入两种代币，获得 JCP-LP
    function addLiquidity(uint256 _jcpAmount, uint256 _jcpusdAmount) external nonReentrant returns (uint256 liquidity) {
        if (totalSupply() == 0) {
            // 初始定价：第一个注资的人决定价格。几何平均数公式：sqrt(x * y)
            liquidity = _sqrt(_jcpAmount * _jcpusdAmount);
        } else {
            // 之后必须按当前池子比例注入，取两者中较小的一方发放 LP
            uint256 jcpShare = (_jcpAmount * totalSupply()) / jcpReserve;
            uint256 jcpusdShare = (_jcpusdAmount * totalSupply()) / jcpusdReserve;
            liquidity = jcpShare < jcpusdShare ? jcpShare : jcpusdShare;
        }

        require(liquidity > 0, "Minted liquidity must > 0");

        // 搬钱：从学生钱包搬到合约
        jcpToken.transferFrom(msg.sender, address(this), _jcpAmount);
        jcpusdToken.transferFrom(msg.sender, address(this), _jcpusdAmount);

        _mint(msg.sender, liquidity); // 铸造股权证明
        _updateReserves();
        emit Mint(msg.sender, _jcpAmount, _jcpusdAmount, liquidity);
    }

    // 退出流动性：销毁 JCP-LP，取回本金 + 手续费收益
    function removeLiquidity(uint256 _lpAmount) external nonReentrant returns (uint256 jcpAmount, uint256 jcpusdAmount) {
        require(_lpAmount > 0, "Invalid LP amount");
        uint256 totalLP = totalSupply();

        // 计算应退回的资产数量
        jcpAmount = (_lpAmount * jcpReserve) / totalLP;
        jcpusdAmount = (_lpAmount * jcpusdReserve) / totalLP;

        _burn(msg.sender, _lpAmount); // 销毁股权
        jcpToken.transfer(msg.sender, jcpAmount);
        jcpusdToken.transfer(msg.sender, jcpusdAmount);

        _updateReserves();
        emit Burn(msg.sender, jcpAmount, jcpusdAmount, _lpAmount);
    }

    // --- 3. 兑换系统 (Swap) ---

    // 预览函数：在 Swap 之前输入金额，查看能换回多少（包含手续费和滑点）
    function previewSwap(uint256 _amountIn, bool _isJCPToUSD) public view returns (uint256 amountOut) {
        if (_isJCPToUSD) {
            return _getAmountOut(_amountIn, jcpReserve, jcpusdReserve);
        } else {
            return _getAmountOut(_amountIn, jcpusdReserve, jcpReserve);
        }
    }

    // 方向 A: 用 JCP 换 JCPUSD
    function swapJCPForJCPUSD(uint256 _jcpIn) external nonReentrant {
        uint256 jcpusdOut = previewSwap(_jcpIn, true);
        jcpToken.transferFrom(msg.sender, address(this), _jcpIn);
        jcpusdToken.transfer(msg.sender, jcpusdOut);
        _updateReserves();
        emit Swap(msg.sender, _jcpIn, jcpusdOut, true);
    }

    // 方向 B: 用 JCPUSD 换 JCP
    function swapJCPUSDForJCP(uint256 _jcpusdIn) external nonReentrant {
        uint256 jcpOut = previewSwap(_jcpusdIn, false);
        jcpusdToken.transferFrom(msg.sender, address(this), _jcpusdIn);
        jcpToken.transfer(msg.sender, jcpOut);
        _updateReserves();
        emit Swap(msg.sender, _jcpusdIn, jcpOut, false);
    }

    // --- 4. 内部数学与管理 (Utils) ---

    // 核心恒定乘积公式：(x + delta_x) * (y - delta_y) = k
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        require(reserveIn > 0 && reserveOut > 0, "Empty pool");
        uint256 amountInWithFee = amountIn * feeMultiplier;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function _updateReserves() internal {
        jcpReserve = jcpToken.balanceOf(address(this));
        jcpusdReserve = jcpusdToken.balanceOf(address(this));
    }

    // 开方函数：用于计算初始 LP 份额
    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // 老师专属权限：调整手续费（例如输入 990 代表 1% 手续费）
    function setFee(uint256 _newFeeMultiplier) external onlyOwner {
        require(_newFeeMultiplier <= 1000, "Fee ratio error");
        feeMultiplier = _newFeeMultiplier;
    }
}