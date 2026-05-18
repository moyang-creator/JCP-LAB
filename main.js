const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
    const win = new BrowserWindow({
        width: 1200,
        height: 900,
        title: "暨南大学419课室经济仿真实验v1.0（版权归莫老师所有）",
        webPreferences: {
            nodeIntegration: false, // 安全建议：由于涉及 ethers.js，保持 false
            contextIsolation: true
        }
    });

    // 加载您刚才上传的 HTML 文件
    win.loadFile('test6JCPv1-5.html');
    
    // 可选：启动时自动打开开发者工具（方便调试合约连接）
    // win.webContents.openDevTools();
}

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});