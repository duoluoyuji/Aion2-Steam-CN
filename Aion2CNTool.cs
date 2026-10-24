using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("AION 2 国际服简繁一键汉化工具")]
[assembly: AssemblyDescription("AION 2 (Steam / PURPLE 正式版) 简繁中文一键汉化工具")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("B站@吃素的佩奇")]
[assembly: AssemblyProduct("Aion2CNTool")]
[assembly: AssemblyCopyright("Copyright © 2026 B站@吃素的佩奇")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]
[assembly: AssemblyVersion("1.3.1.0")]
[assembly: AssemblyFileVersion("1.3.1.0")]

namespace Aion2CN {
    public class ClientTarget {
        public string ClientType { get; set; }
        public string Path { get; set; }

        public override string ToString() {
            return "[" + ClientType + "] " + Path;
        }
    }

    public class MainForm : Form {
        private Panel topPanel;
        private Label lblTitle;
        private Button btnBili;

        private GroupBox grpClients;
        private CheckedListBox chkListClients;
        private Button btnRescan;
        private Button btnBrowse;

        private GroupBox grpActions;
        private Label lblDiscText;
        private CheckBox chkAgree;
        private Button btnInstallZh;
        private Button btnInstallTw;
        private Button btnRestore;

        private GroupBox grpLog;
        private TextBox txtLog;

        private List<ClientTarget> detectedRoots;
        private string toolDir;
        private string zhDir;
        private string zhTwDir;
        // 设计尺寸（96 DPI 基准），高分屏缩放时复用，避免两处硬编码失联
        private const int DesignW = 760;
        private const int DesignH = 725;
        private string currentVersion = "1.3.1";
        private string[] appIds = new string[] { "3393110", "4972320" };

        public MainForm() {
            detectedRoots = new List<ClientTarget>();
            toolDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            zhDir = Path.Combine(toolDir, "zh");
            zhTwDir = Path.Combine(toolDir, "zh-TW");

            InitializeComponent();
        }

        private void InitializeComponent() {
            this.Text = "永恒之塔2 (AION 2) 国际服简繁一键汉化 v" + currentVersion + " - B站@吃素的佩奇";
            this.Size = new Size(DesignW, DesignH);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.BackColor = Color.FromArgb(243, 244, 246);
            this.ForeColor = Color.FromArgb(31, 41, 55);
            this.Font = new Font("Microsoft YaHei UI", 9.5f);

            // ================= 顶部横幅 =================
            topPanel = new Panel();
            topPanel.Dock = DockStyle.Top;
            topPanel.Height = 72;
            topPanel.BackColor = Color.FromArgb(255, 255, 255);

            lblTitle = new Label();
            lblTitle.Text = "永恒之塔2 (AION 2) 国际服简繁一键汉化";
            lblTitle.Font = new Font("Microsoft YaHei UI", 16f, FontStyle.Bold);
            lblTitle.ForeColor = Color.FromArgb(17, 24, 39);
            lblTitle.Location = new Point(20, 18);
            lblTitle.AutoSize = true;

            btnBili = new Button();
            btnBili.Text = "关注作者B站";
            btnBili.Location = new Point(610, 18);
            btnBili.Size = new Size(115, 36);
            btnBili.BackColor = Color.FromArgb(251, 114, 153);
            btnBili.ForeColor = Color.White;
            btnBili.FlatStyle = FlatStyle.Flat;
            btnBili.FlatAppearance.BorderSize = 0;
            btnBili.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);
            btnBili.Cursor = Cursors.Hand;
            btnBili.Click += (s, e) => {
                try { Process.Start("https://space.bilibili.com/3379443"); } catch {}
            };

            topPanel.Controls.Add(lblTitle);
            topPanel.Controls.Add(btnBili);
            this.Controls.Add(topPanel);

            // ================= 客户端扫描区域 =================
            grpClients = new GroupBox();
            grpClients.Text = " 游戏客户端检测 (支持 Steam / 紫P 同时检测) ";
            grpClients.Location = new Point(20, 85);
            grpClients.Size = new Size(705, 140);
            grpClients.ForeColor = Color.FromArgb(31, 41, 55);
            grpClients.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);

            chkListClients = new CheckedListBox();
            chkListClients.Location = new Point(15, 25);
            chkListClients.Size = new Size(535, 100);
            chkListClients.CheckOnClick = true;
            chkListClients.BackColor = Color.FromArgb(255, 255, 255);
            chkListClients.ForeColor = Color.FromArgb(17, 24, 39);
            chkListClients.Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Regular);

            // 重新扫描按钮：纯白卡片式底色 + 浅灰边框 + 灰黑文字
            btnRescan = new Button();
            btnRescan.Text = "重新扫描";
            btnRescan.Location = new Point(565, 28);
            btnRescan.Size = new Size(125, 42);
            btnRescan.BackColor = Color.FromArgb(255, 255, 255);
            btnRescan.ForeColor = Color.FromArgb(55, 65, 81);
            btnRescan.FlatStyle = FlatStyle.Flat;
            btnRescan.FlatAppearance.BorderColor = Color.FromArgb(209, 213, 219);
            btnRescan.FlatAppearance.BorderSize = 1;
            btnRescan.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);
            btnRescan.Cursor = Cursors.Hand;
            btnRescan.Click += (s, e) => { RunScan(); };

            // 手动选择路径按钮：纯白卡片式底色 + 浅灰边框 + 灰黑文字
            btnBrowse = new Button();
            btnBrowse.Text = "手动选择路径";
            btnBrowse.Location = new Point(565, 80);
            btnBrowse.Size = new Size(125, 42);
            btnBrowse.BackColor = Color.FromArgb(255, 255, 255);
            btnBrowse.ForeColor = Color.FromArgb(55, 65, 81);
            btnBrowse.FlatStyle = FlatStyle.Flat;
            btnBrowse.FlatAppearance.BorderColor = Color.FromArgb(209, 213, 219);
            btnBrowse.FlatAppearance.BorderSize = 1;
            btnBrowse.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);
            btnBrowse.Cursor = Cursors.Hand;
            btnBrowse.Click += (s, e) => { BrowsePath(); };

            grpClients.Controls.Add(chkListClients);
            grpClients.Controls.Add(btnRescan);
            grpClients.Controls.Add(btnBrowse);
            this.Controls.Add(grpClients);

            // ================= 操作按钮与免责区域 =================
            grpActions = new GroupBox();
            grpActions.Text = " 汉化与还原操作 ";
            grpActions.Location = new Point(20, 235);
            grpActions.Size = new Size(705, 185);
            grpActions.ForeColor = Color.FromArgb(31, 41, 55);
            grpActions.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);

            lblDiscText = new Label();
            lblDiscText.Text = "★ 本工具完全开源免费，仅供交流学习，严禁任何商业/倒卖牟利！\n★ 请在完全关闭游戏客户端后再进行安装或还原，避免文件占用产生写入错误。";
            lblDiscText.Location = new Point(15, 22);
            lblDiscText.Size = new Size(675, 42);
            lblDiscText.Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Regular);
            lblDiscText.ForeColor = Color.FromArgb(75, 85, 99);

            // 风险知晓协议：暖琥珀橙色
            chkAgree = new CheckBox();
            chkAgree.Text = "我已知晓修改客户端的风险，自愿承担相关风险，并承诺仅用于个人学习交流";
            chkAgree.Location = new Point(15, 68);
            chkAgree.AutoSize = true;
            chkAgree.Font = new Font("Microsoft YaHei UI", 9f, FontStyle.Regular);
            chkAgree.ForeColor = Color.FromArgb(180, 83, 9);
            chkAgree.CheckedChanged += (s, e) => {
                if (chkAgree.Checked) {
                    btnInstallZh.Enabled = true;
                    btnInstallZh.BackColor = Color.FromArgb(22, 163, 74);
                    btnInstallZh.ForeColor = Color.White;

                    btnInstallTw.Enabled = true;
                    btnInstallTw.BackColor = Color.FromArgb(2, 132, 199);
                    btnInstallTw.ForeColor = Color.White;

                    AppendLog("已确认知晓风险，汉化功能已解锁。");
                } else {
                    btnInstallZh.Enabled = false;
                    btnInstallZh.BackColor = Color.FromArgb(229, 231, 235);
                    btnInstallZh.ForeColor = Color.FromArgb(156, 163, 175);

                    btnInstallTw.Enabled = false;
                    btnInstallTw.BackColor = Color.FromArgb(229, 231, 235);
                    btnInstallTw.ForeColor = Color.FromArgb(156, 163, 175);

                    AppendLog("已取消勾选协议，汉化功能已锁定。");
                }
            };

            // 简体汉化按钮
            btnInstallZh = new Button();
            btnInstallZh.Text = "一键应用【简体中文】";
            btnInstallZh.Location = new Point(15, 100);
            btnInstallZh.Size = new Size(215, 60);
            btnInstallZh.BackColor = Color.FromArgb(229, 231, 235);
            btnInstallZh.ForeColor = Color.FromArgb(156, 163, 175);
            btnInstallZh.FlatStyle = FlatStyle.Flat;
            btnInstallZh.FlatAppearance.BorderSize = 0;
            btnInstallZh.Font = new Font("Microsoft YaHei UI", 11f, FontStyle.Bold);
            btnInstallZh.Cursor = Cursors.Hand;
            btnInstallZh.Enabled = false;
            btnInstallZh.Click += (s, e) => { ExecuteInstall("zh", "简体中文", zhDir); };

            // 繁体汉化按钮
            btnInstallTw = new Button();
            btnInstallTw.Text = "一键应用【繁体中文】";
            btnInstallTw.Location = new Point(245, 100);
            btnInstallTw.Size = new Size(215, 60);
            btnInstallTw.BackColor = Color.FromArgb(229, 231, 235);
            btnInstallTw.ForeColor = Color.FromArgb(156, 163, 175);
            btnInstallTw.FlatStyle = FlatStyle.Flat;
            btnInstallTw.FlatAppearance.BorderSize = 0;
            btnInstallTw.Font = new Font("Microsoft YaHei UI", 11f, FontStyle.Bold);
            btnInstallTw.Cursor = Cursors.Hand;
            btnInstallTw.Enabled = false;
            btnInstallTw.Click += (s, e) => { ExecuteInstall("zh-TW", "繁体中文", zhTwDir); };

            // 一键还原官方默认英文：永远可用（Enabled = true，无需勾选协议！），醒目鲜红色
            btnRestore = new Button();
            btnRestore.Text = "一键还原官方默认英文";
            btnRestore.Location = new Point(475, 100);
            btnRestore.Size = new Size(215, 60);
            btnRestore.BackColor = Color.FromArgb(220, 38, 38);
            btnRestore.ForeColor = Color.White;
            btnRestore.FlatStyle = FlatStyle.Flat;
            btnRestore.FlatAppearance.BorderSize = 0;
            btnRestore.Font = new Font("Microsoft YaHei UI", 11f, FontStyle.Bold);
            btnRestore.Cursor = Cursors.Hand;
            btnRestore.Enabled = true; // ★ 永远无需勾选，直接可用！
            btnRestore.Click += (s, e) => { ExecuteRestore(); };

            grpActions.Controls.Add(lblDiscText);
            grpActions.Controls.Add(chkAgree);
            grpActions.Controls.Add(btnInstallZh);
            grpActions.Controls.Add(btnInstallTw);
            grpActions.Controls.Add(btnRestore);
            this.Controls.Add(grpActions);

            // ================= 实时日志区域 =================
            grpLog = new GroupBox();
            grpLog.Text = " 实时日志与状态显示 ";
            grpLog.Location = new Point(20, 430);
            grpLog.Size = new Size(705, 240);
            grpLog.ForeColor = Color.FromArgb(31, 41, 55);
            grpLog.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Bold);

            txtLog = new TextBox();
            txtLog.Location = new Point(15, 25);
            txtLog.Size = new Size(675, 200);
            txtLog.Multiline = true;
            txtLog.ReadOnly = true;
            txtLog.ScrollBars = ScrollBars.Vertical;
            txtLog.BackColor = Color.FromArgb(17, 24, 39);
            txtLog.ForeColor = Color.FromArgb(52, 211, 153);
            txtLog.Font = new Font("Consolas", 9f);

            grpLog.Controls.Add(txtLog);
            this.Controls.Add(grpLog);

            this.Load += (s, e) => {
                AppendLog("欢迎使用 AION 2 国际服简繁一键汉化工具 v" + currentVersion + "！");
                AppendLog("★ 完全免费开源，严禁倒卖牟利 | 制作维护: B站@吃素的佩奇");
                AppendLog("==========================================================");
                RunScan();
            };

            // 高分屏适配：进程已声明系统 DPI 感知（见 app.manifest），字体随 DPI 自动缩放，
            // 控件矩形与窗口在此按同一比例统一放大（AutoScaleMode 对纯代码窗体不可靠）。
            // 注意：用桌面 DC 读 DPI，不提前创建窗口句柄，否则 CenterScreen 会按缩放前尺寸计算导致窗口偏移。
            try {
                float dpi;
                using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) {
                    dpi = g.DpiX / 96f;
                }
                if (dpi > 1f) {
                    this.Scale(new SizeF(dpi, dpi));
                    // Scale 对顶层窗体按客户区缩放，此处覆盖为 设计尺寸×DPI 的外框精确值，并限制不超出屏幕工作区
                    Rectangle wa = Screen.PrimaryScreen.WorkingArea;
                    this.Size = new Size(
                        Math.Min((int)Math.Round(DesignW * dpi), wa.Width),
                        Math.Min((int)Math.Round(DesignH * dpi), wa.Height));
                }
            } catch (Exception ex) {
                AppendLog("【警告】DPI 缩放失败，界面可能偏小: " + ex.Message);
            }
        }

        private void AppendLog(string msg) {
            string line = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + "\r\n";
            txtLog.AppendText(line);
        }

        // ================= 客户端判定（精准排除台服） =================
        // 国际服判定：L10N\Text 必须存在，且不得包含 zh-TW 语言目录。
        // zh-TW 语言包是台服独有特征（国际服语言列表只有 de/en/es/fr/ja/ko/pt/ru，无中文），与安装路径无关
        private static bool IsIntlRoot(string root) {
            string text = Path.Combine(root, @"Aion2\Content\Paks\L10N\Text");
            return Directory.Exists(text) && !Directory.Exists(Path.Combine(text, "zh-TW"));
        }

        // ================= 安全文件操作辅助方法（解决只读属性与文件锁占用） =================
        private static void SafeCopyFile(string src, string dst) {
            if (!File.Exists(src)) {
                throw new FileNotFoundException("源文件不存在: " + src);
            }

            string dstDir = Path.GetDirectoryName(dst);
            if (!Directory.Exists(dstDir)) {
                Directory.CreateDirectory(dstDir);
            }

            // 1. 如果目标已存在，先行清除其只读和隐藏属性（这是导致“访问被拒绝”的最常见元凶）
            if (File.Exists(dst)) {
                try {
                    File.SetAttributes(dst, FileAttributes.Normal);
                } catch {}
            }

            // 2. 带自动重试与强行覆盖的复制机制（应对杀软临时扫描、轻微文件锁）
            Exception lastEx = null;
            for (int retry = 1; retry <= 5; retry++) {
                try {
                    File.Copy(src, dst, true);
                    try { File.SetAttributes(dst, FileAttributes.Normal); } catch {}
                    return;
                } catch (Exception ex) {
                    lastEx = ex;
                    // 尝试删除后重写
                    try {
                        if (File.Exists(dst)) {
                            File.SetAttributes(dst, FileAttributes.Normal);
                            File.Delete(dst);
                            File.Copy(src, dst, true);
                            return;
                        }
                    } catch {}
                    if (retry < 5) {
                        Thread.Sleep(300);
                    }
                }
            }

            if (lastEx != null) {
                throw lastEx;
            }
        }

        private static void SafeDeleteFile(string path) {
            if (File.Exists(path)) {
                try {
                    File.SetAttributes(path, FileAttributes.Normal);
                    File.Delete(path);
                } catch {}
            }
        }

        private void BrowsePath() {
            using (var dlg = new FolderBrowserDialog()) {
                dlg.Description = "请选择 AION 2 游戏根目录（包含 Aion2 文件夹的那一层目录）：";
                dlg.ShowNewFolderButton = false;
                if (dlg.ShowDialog() == DialogResult.OK) {
                    string sel = dlg.SelectedPath.TrimEnd('\\', '/');
                    string checkExe = Path.Combine(sel, @"Aion2\Binaries\Win64\Aion2-Win64-Shipping.exe");
                    if (File.Exists(checkExe) || IsIntlRoot(sel)) {
                        foreach (var cur in detectedRoots) {
                            if (string.Equals(cur.Path.TrimEnd('\\', '/'), sel, StringComparison.OrdinalIgnoreCase)) {
                                MessageBox.Show("该客户端路径已存在于列表中！", "已存在", MessageBoxButtons.OK, MessageBoxIcon.Information);
                                return;
                            }
                        }
                        var target = new ClientTarget { ClientType = "手动指定客户端", Path = sel };
                        detectedRoots.Add(target);
                        chkListClients.Items.Add(target.ToString(), true);
                        AppendLog("手动添加游戏目录成功: " + sel);
                    } else {
                        MessageBox.Show("所选目录未检测到有效 AION 2 游戏文件！\n请确保所选目录包含 Aion2 文件夹。", "路径无效", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    }
                }
            }
        }

        private List<string> GetSelectedTargets() {
            var res = new List<string>();
            for (int i = 0; i < chkListClients.Items.Count; i++) {
                if (chkListClients.GetItemChecked(i)) {
                    if (i < detectedRoots.Count) {
                        res.Add(detectedRoots[i].Path);
                    }
                }
            }
            return res;
        }

        private void ReleaseFileLocks() {
            AppendLog("正在检查游戏冲突进程并释放文件锁...");
            string[] conflictList = new string[] { 
                "Aion2", "Aion2-Win64-Shipping", "AION2", "AION2-Win64-Shipping", 
                "NCLauncher", "NCLauncher2", "Purple", "PurpleApp" 
            };
            foreach (var name in conflictList) {
                try {
                    foreach (var p in Process.GetProcessesByName(name)) {
                        AppendLog("-> 检测到运行中的进程: " + name + " (PID: " + p.Id + ")，正在安全关闭...");
                        try {
                            p.Kill();
                            p.WaitForExit(1000);
                        } catch {}
                    }
                } catch {}
            }
            Thread.Sleep(300);
        }

        private void RunScan() {
            chkListClients.Items.Clear();
            detectedRoots.Clear();
            AppendLog("正在执行全盘与注册表深度扫描...");

            detectedRoots = ScanAllGameRoots();

            if (detectedRoots.Count == 0) {
                AppendLog("【提示】未自动扫描到 AION 2 游戏目录。请点击右侧「手动选择路径」按钮指定。");
            } else {
                foreach (var t in detectedRoots) {
                    chkListClients.Items.Add(t.ToString(), true);
                    AppendLog("-> 发现客户端: [" + t.ClientType + "] " + t.Path);
                }
                AppendLog("扫描完成！成功识别到 " + detectedRoots.Count + " 个有效游戏客户端版本。");
            }
        }

        private void AddTargetIfNotExists(List<ClientTarget> list, string clientType, string path) {
            if (string.IsNullOrEmpty(path)) return;
            string cleanPath = path.TrimEnd('\\', '/');
            foreach (var cur in list) {
                if (string.Equals(cur.Path.TrimEnd('\\', '/'), cleanPath, StringComparison.OrdinalIgnoreCase)) {
                    return;
                }
            }
            list.Add(new ClientTarget { ClientType = clientType, Path = cleanPath });
        }

        private List<ClientTarget> ScanAllGameRoots() {
            var results = new List<ClientTarget>();
            var drives = DriveInfo.GetDrives();

            // 1. Steam 扫描
            AppendLog("[扫描] 正在全盘检索 Steam 游戏库清单...");
            var steamAppsCandidates = new List<string>();
            foreach (var d in drives) {
                if (!d.IsReady) continue;
                string root = d.RootDirectory.FullName;
                string[] candidates = new string[] {
                    Path.Combine(root, @"SteamLibrary\steamapps"),
                    Path.Combine(root, "steamapps"),
                    Path.Combine(root, @"Program Files (x86)\Steam\steamapps"),
                    Path.Combine(root, @"Program Files\Steam\steamapps"),
                    Path.Combine(root, @"Steam\steamapps")
                };
                foreach (var c in candidates) {
                    if (Directory.Exists(c) && !steamAppsCandidates.Contains(c)) {
                        steamAppsCandidates.Add(c);
                    }
                }
            }

            try {
                using (var steamKey = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam")) {
                    if (steamKey != null) {
                        object p = steamKey.GetValue("SteamPath");
                        if (p != null) {
                            string sa = Path.Combine(p.ToString().Replace('/', '\\'), "steamapps");
                            if (Directory.Exists(sa) && !steamAppsCandidates.Contains(sa)) {
                                steamAppsCandidates.Add(sa);
                            }
                        }
                    }
                }
            } catch {}

            foreach (var sa in steamAppsCandidates) {
                foreach (var aid in appIds) {
                    string acf = Path.Combine(sa, "appmanifest_" + aid + ".acf");
                    if (File.Exists(acf)) {
                        try {
                            string content = File.ReadAllText(acf);
                            var m = Regex.Match(content, "\"installdir\"\\s+\"([^\"]+)\"");
                            if (m.Success) {
                                string gameDir = Path.Combine(Path.Combine(sa, "common"), m.Groups[1].Value);
                                if (IsIntlRoot(gameDir)) {
                                    string label = (aid == "3393110") ? "Steam 国际正式服" : "Steam 测试服";
                                    AddTargetIfNotExists(results, label, gameDir);
                                }
                            }
                        } catch {}
                    }
                }

                string common = Path.Combine(sa, "common");
                if (Directory.Exists(common)) {
                    try {
                        foreach (var dir in Directory.GetDirectories(common)) {
                            if (IsIntlRoot(dir)) {
                                string dirName = Path.GetFileName(dir);
                                AddTargetIfNotExists(results, "Steam 游戏库 (" + dirName + ")", dir);
                            }
                        }
                    } catch {}
                }
            }

            // 2. PURPLE (紫P) 扫描
            AppendLog("[扫描] 正在执行 NCSoft PURPLE (紫P) 注册表与磁盘检索...");
            CheckPlayncKey(Registry.LocalMachine, @"SOFTWARE\plaync", results);
            CheckPlayncKey(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\plaync", results);
            CheckPlayncKey(Registry.CurrentUser, @"SOFTWARE\plaync", results);

            CheckUninstallKey(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", results);
            CheckUninstallKey(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", results);
            CheckUninstallKey(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", results);

            // 磁盘通用路径检索
            foreach (var d in drives) {
                if (!d.IsReady) continue;
                string r = d.RootDirectory.FullName;
                string[] purpleCandidates = new string[] {
                    Path.Combine(r, "AION 2"),
                    Path.Combine(r, "Aion2"),
                    Path.Combine(r, @"Games\AION 2"),
                    Path.Combine(r, @"Games\Aion2"),
                    Path.Combine(r, @"PurpleGames\AION 2"),
                    Path.Combine(r, @"PurpleGames\Aion2"),
                    Path.Combine(r, @"Purple\Games\AION 2"),
                    Path.Combine(r, @"NC\AION 2"),
                    Path.Combine(r, @"NCSOFT\AION 2"),
                    Path.Combine(r, @"NCSOFT\Purple\Games\AION 2"),
                    Path.Combine(r, @"Program Files\NCSOFT\Purple\AION 2"),
                    Path.Combine(r, @"Program Files (x86)\NCSOFT\Purple\AION 2")
                };
                foreach (var pc in purpleCandidates) {
                    if (IsIntlRoot(pc)) {
                        AddTargetIfNotExists(results, "NCSoft PURPLE 客户端 (磁盘扫描)", pc);
                    }
                }
            }

            return results;
        }

        private void CheckPlayncKey(RegistryKey rootKey, string subKeyPath, List<ClientTarget> results) {
            try {
                using (var k = rootKey.OpenSubKey(subKeyPath)) {
                    if (k != null) {
                        foreach (var sub in k.GetSubKeyNames()) {
                            using (var app = k.OpenSubKey(sub)) {
                                if (app != null) {
                                    object baseDir = app.GetValue("BaseDir");
                                    if (baseDir != null) {
                                        string b = baseDir.ToString().TrimEnd('\\', '/');
                                        if (IsIntlRoot(b)) {
                                            AddTargetIfNotExists(results, "NCSoft PURPLE 客户端 (注册表定位)", b);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {}
        }

        private void CheckUninstallKey(RegistryKey rootKey, string subKeyPath, List<ClientTarget> results) {
            try {
                using (var k = rootKey.OpenSubKey(subKeyPath)) {
                    if (k != null) {
                        foreach (var sub in k.GetSubKeyNames()) {
                            using (var app = k.OpenSubKey(sub)) {
                                if (app != null) {
                                    object name = app.GetValue("DisplayName");
                                    object loc = app.GetValue("InstallLocation");
                                    if (name != null && loc != null) {
                                        string n = name.ToString();
                                        string l = loc.ToString().TrimEnd('\\', '/');
                                        if ((n.IndexOf("AION", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("Purple", StringComparison.OrdinalIgnoreCase) >= 0) &&
                                            IsIntlRoot(l)) {
                                            AddTargetIfNotExists(results, "NCSoft PURPLE 客户端 (系统卸载表)", l);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {}
        }

        private void ExecuteInstall(string langCode, string langTitle, string sourceDir) {
            var targets = GetSelectedTargets();
            if (targets.Count == 0) {
                MessageBox.Show("请至少勾选一个目标游戏客户端！", "未选择客户端", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            string datFile = Path.Combine(sourceDir, "L10NString.dat");
            string pakFile = Path.Combine(sourceDir, "pakchunk502000-Windows_0_P.pak");

            if (!File.Exists(datFile) || !File.Exists(pakFile)) {
                AppendLog("【错误】未找到汉化数据文件: " + sourceDir);
                MessageBox.Show("未在 [" + sourceDir + "] 找到汉化数据文件 (L10NString.dat 或 pakchunk502000-Windows_0_P.pak)！\n请确保汉化工具与 zh / zh-TW 文件夹放在同一目录下！", "缺失数据文件", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            ReleaseFileLocks();

            int count = 0;
            try {
                for (int i = 0; i < targets.Count; i++) {
                    string root = targets[i];
                    count++;
                    AppendLog("==========================================================");
                    AppendLog(">>> 正在处理目标客户端 [" + count + "/" + targets.Count + "]: " + root);

                    string backupDir   = Path.Combine(root, "Aion2_English_Backup_Safe");
                    string enUsL10nDir = Path.Combine(root, @"Aion2\Content\L10N\Text\en-US");
                    string enUsPaksDir = Path.Combine(root, @"Aion2\Content\Paks\L10N\Text\en-US");

                    // 备份
                    if (!Directory.Exists(backupDir)) {
                        AppendLog("-> 正在创建官方原版英文安全备份...");
                        Directory.CreateDirectory(backupDir);
                        string curPak = Path.Combine(enUsPaksDir, "pakchunk502000-Windows_0_P.pak");
                        if (File.Exists(curPak) && new FileInfo(curPak).Length > 1000) {
                            foreach (string file in Directory.GetFiles(enUsPaksDir)) {
                                SafeCopyFile(file, Path.Combine(backupDir, Path.GetFileName(file)));
                            }
                            AppendLog("-> 官方原版英文文件已安全备份至: " + backupDir);
                        }
                    } else {
                        AppendLog("-> 本地已存在安全备份，跳过覆盖。");
                    }

                    // 释放 L10NString.dat
                    AppendLog("-> 正在部署 " + langTitle + " 数据表...");
                    Directory.CreateDirectory(enUsL10nDir);
                    SafeCopyFile(datFile, Path.Combine(enUsL10nDir, "L10NString.dat"));

                    // 注入虚幻5回退机制 Stub pak
                    AppendLog("-> 正在注入虚幻5引擎本地化回退机制 (Stub)...");
                    string sig  = Path.Combine(enUsPaksDir, "pakchunk502000-Windows_0_P.sig");
                    string ucas = Path.Combine(enUsPaksDir, "pakchunk502000-Windows_0_P.ucas");
                    string utoc = Path.Combine(enUsPaksDir, "pakchunk502000-Windows_0_P.utoc");
                    SafeDeleteFile(sig);
                    SafeDeleteFile(ucas);
                    SafeDeleteFile(utoc);

                    Directory.CreateDirectory(enUsPaksDir);
                    SafeCopyFile(pakFile, Path.Combine(enUsPaksDir, "pakchunk502000-Windows_0_P.pak"));
                    AppendLog("-> 该客户端 " + langTitle + " 汉化部署完成！");
                }

                AppendLog("==========================================================");
                AppendLog("恭喜！已全部成功应用 " + langTitle + " (共处理 " + count + " 个客户端)！");
                AppendLog("【核心提示】游戏内语言请保持默认英文（English），进入游戏即可直接显示中文！");
                AppendLog("==========================================================");

                MessageBox.Show("AION 2 " + langTitle + "汉化补丁安装成功 (共处理 " + count + " 个客户端)！\n\n【提示】：游戏内语言保持默认英文（English）即可直接享受中文！\n\n制作：B站@吃素的佩奇\n欢迎关注获取最新补丁与动态！", "汉化成功 - B站@吃素的佩奇", MessageBoxButtons.OK, MessageBoxIcon.Information);
            } catch (Exception ex) {
                AppendLog("【错误】文件写入失败: " + ex.Message);
                MessageBox.Show("汉化部署失败！\n\n【可能原因与解决办法】：\n1. 游戏或紫色 PURPLE 客户端仍在后台运行（文件被占用）：请打开任务管理器结束相关进程后重试；\n2. 文件夹被设置了只读属性或权限不足：请右键【以管理员身份运行】本工具；\n3. 杀毒软件（360/火绒/Defender）拦截了游戏文件修改。\n\n详细系统报错：" + ex.Message, "写入受阻", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ExecuteRestore() {
            var targets = GetSelectedTargets();
            if (targets.Count == 0) {
                MessageBox.Show("请至少勾选一个目标游戏客户端！", "未选择客户端", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            ReleaseFileLocks();

            int count = 0;
            try {
                for (int i = 0; i < targets.Count; i++) {
                    string root = targets[i];
                    count++;
                    AppendLog("==========================================================");
                    AppendLog(">>> 正在还原目标客户端 [" + count + "/" + targets.Count + "]: " + root);

                    string backupDir   = Path.Combine(root, "Aion2_English_Backup_Safe");
                    string enUsL10nDir = Path.Combine(root, @"Aion2\Content\L10N\Text\en-US");
                    string enUsPaksDir = Path.Combine(root, @"Aion2\Content\Paks\L10N\Text\en-US");

                    // 删除外置数据
                    string looseDat = Path.Combine(enUsL10nDir, "L10NString.dat");
                    SafeDeleteFile(looseDat);
                    AppendLog("-> 已成功移除外置汉化数据表。");

                    // 还原备份
                    if (Directory.Exists(backupDir)) {
                        AppendLog("-> 正在从安全备份中还原官方原版英文包与签名...");
                        Directory.CreateDirectory(enUsPaksDir);
                        foreach (string file in Directory.GetFiles(backupDir)) {
                            SafeCopyFile(file, Path.Combine(enUsPaksDir, Path.GetFileName(file)));
                        }
                        AppendLog("-> 已成功恢复为官方原版英文状态！");
                    } else {
                        AppendLog("-> 未检测到本地安全备份，如果游戏文件缺失，请在 Steam/PURPLE 中验证游戏完整性。");
                    }
                }

                AppendLog("==========================================================");
                AppendLog("官方原版英文还原完成 (共处理 " + count + " 个客户端)！");
                AppendLog("==========================================================");

                MessageBox.Show("AION 2 官方原版英文已成功还原 (共处理 " + count + " 个客户端)！\n\n游戏客户端已完全恢复为纯净官方原版状态。\n随时可重新运行一键汉化！\n\n制作：B站@吃素的佩奇", "还原成功 - B站@吃素的佩奇", MessageBoxButtons.OK, MessageBoxIcon.Information);
            } catch (Exception ex) {
                AppendLog("【错误】还原文件失败: " + ex.Message);
                MessageBox.Show("还原失败！\n\n【可能原因与解决办法】：\n1. 游戏或启动器仍在后台运行：请彻底退出后再重试；\n2. 权限不足：请右键【以管理员身份运行】本工具。\n\n详细系统报错：" + ex.Message, "还原受阻", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    static class Program {
        [STAThread]
        static void Main() {
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            AppDomain.CurrentDomain.UnhandledException += (s, e) => {
                Exception ex = e.ExceptionObject as Exception;
                string msg = (ex != null) ? ex.Message : "未知异常";
                MessageBox.Show("程序发生异常: " + msg + "\n建议以管理员身份重新运行。", "提示", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            };

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
