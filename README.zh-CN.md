# kernel-lore-hunter

**把一篇文章、一个 commit、一个内核符号，变成真正的 patchset、真正的邮件讨论串和一个经过核实的合并状态。**

lore.kernel.org、git.kernel.org、lkml.org 全站挂在
[Anubis](https://github.com/TecharoHQ/anubis)（JS 工作量证明反爬）后面，
直接 `curl` 只会拿到 `403` 和一个约 1.1 KB 的假页面。这个 skill 教你的 agent
用五条能穿过去的通道，再加上一套「把『有人发过关于 page cache 的东西』还原成
**代码分支 + 邮件串 + 版本状态**」的标准作业流程，每条结论都带永久可点击链接。

> 支持 Claude Code、Codex、Cursor、Gemini CLI、OpenCode、GitHub Copilot、
> Windsurf、Cline、Goose、Amp、MiniMax Code、DSH，以及一切遵循
> [Agent Skills](https://agentskills.io) 标准的 agent。

[English](./README.md) · [SKILL.md](./SKILL.md) · [MIT 协议](./LICENSE)

---

## 它到底做什么

输入「这篇讲 Linus 用 LLM 重写 page cache 的文章，帮我找出 patchset」，
产出是：

| | |
|---|---|
| **代码** | 分支、commit 区间、这个 series 的每一版 |
| **讨论** | 根邮件、真正关键的 3–6 条 review、谁在吵什么 |
| **前史** | 同一问题更早的几次尝试，按时间排 |
| **校正** | 文章哪里错了——日期、补丁数量、分支归属 |
| **状态** | 已合并 / 仍在 RFC / 被取代，**并写明核查日期** |

后两行才是重点。二手内核报道几乎每次都有错，而一个不核查就照抄的 agent
产出的是「自信的胡话」。

---

## 安装

### 1. `npx skills`（最快——支持 40+ 种 agent）

```bash
npx skills add WizardHowlhaha/kernel-lore-hunter -g
```

只装给特定 agent：

```bash
npx skills add WizardHowlhaha/kernel-lore-hunter -g -a claude-code -a codex
npx skills list -g                 # 查看已装内容
```

### 2. clone + 安装脚本（推荐——可审计，一份真身，多端共用）

```bash
git clone https://github.com/WizardHowlhaha/kernel-lore-hunter.git
cd kernel-lore-hunter
./install.sh                        # 用户级，自动装给所有检测到的 agent
./install.sh --dry-run              # 先预览
./install.sh -a claude-code -a cursor
./install.sh --scope project --project-dir ~/work/linux-mm
```

脚本在 `~/.agents/skills/kernel-lore-hunter` 保留**唯一真身**，其余 agent 全部
软链过去。改一次，所有端同时更新。

### 3. 手动复制

```bash
git clone https://github.com/WizardHowlhaha/kernel-lore-hunter.git \
  ~/.agents/skills/kernel-lore-hunter
```

Claude Code 不读 `~/.agents/skills/`，补一个软链：

```bash
mkdir -p ~/.claude/skills
ln -s ~/.agents/skills/kernel-lore-hunter ~/.claude/skills/kernel-lore-hunter
```

### 卸载

```bash
./uninstall.sh            # 只移除各 agent 的链接
./uninstall.sh --purge    # 连同真身一起删
```

---

## 各 agent 的查找路径

`install.sh` 会替你连对目录，这张表是参考。

| Agent | 用户级 | 项目级 | `install.sh` 覆盖 |
|---|---|---|---|
| 通用（`~/.agents/skills`） | `~/.agents/skills/kernel-lore-hunter` | `.agents/skills/kernel-lore-hunter` | ✅ 真身 |
| Claude Code | `~/.claude/skills/kernel-lore-hunter` | `.claude/skills/kernel-lore-hunter` | ✅ |
| Codex | `~/.codex/skills/kernel-lore-hunter` | `.codex/skills/kernel-lore-hunter` | ✅ |
| Cursor | `~/.cursor/skills/kernel-lore-hunter` | `.cursor/skills/kernel-lore-hunter` | ✅ |
| Gemini CLI | `~/.gemini/skills/kernel-lore-hunter` | `.gemini/skills/kernel-lore-hunter` | ✅ |
| OpenCode | `~/.config/opencode/skills/kernel-lore-hunter` | `.opencode/skills/kernel-lore-hunter` | ✅ |
| GitHub Copilot | `~/.copilot/skills/kernel-lore-hunter` | `.github/skills/kernel-lore-hunter` | ✅ |
| Windsurf | `~/.windsurf/skills/kernel-lore-hunter` | `.windsurf/skills/kernel-lore-hunter` | ✅ |
| Cline | `~/.cline/skills/kernel-lore-hunter` | `.cline/skills/kernel-lore-hunter` | ✅ |
| Goose | `~/.goose/skills/kernel-lore-hunter` | `.goose/skills/kernel-lore-hunter` | ✅ |
| Amp、MiniMax Code、DSH | 读 `~/.agents/skills/` | — | ✅ 真身 |

**Claude Code 是唯一的例外**：它读 `.claude/skills/` 和 `~/.claude/skills/`，
**不读** `~/.agents/skills/`。所以 `install.sh` 专门为它保留软链。

### 验证

```bash
bash ~/.agents/skills/kernel-lore-hunter/scripts/selftest.sh
```

完全离线：校验包结构、frontmatter 是否符合 Agent Skills 规范、每个脚本的语法
以及 `--help` 入口。

然后重启 agent，试着说：

```
找出 <URL / commit / 符号名> 背后的 kernel patchset 和 LKML 讨论
```

---

## 五条通道

整个 skill 存在的理由就是这张表。

| 需求 | 通道 | 耗时 | 说明 |
|---|---|---|---|
| 读某一封邮件 | `scripts/lore.py msg <msgid>` | ~3 s | jina 优先，自动回落 marc.info |
| 回复树 | `scripts/lore.py thread <msgid>` | ~3 s | 只有 jina 提供，会限流，等 1–2 分钟 |
| 找 series | `scripts/patchew.py search` / `series` | ~2 s | cover letter、diffstat、全部 patch |
| 确认分支 | `git ls-remote --heads <repo> 'refs/heads/*kw*'` | ~1 s | **先做这一步**，比任何网页都快 |
| 读 master 上的 commit | `scripts/kbranch.sh <repo> master N` | ~2 s | 走 GitHub 镜像 API |
| 读侧分支的 commit | `scripts/kbranch.sh --git ...` | **3–5 min** | linux.git pack 巨大，必须后台跑 |
| 按月考古 | `lkml.iu.edu/hypermail/linux/kernel/YYMM.N/` | 数秒 | 静态 MHonArc 归档 |
| 是否进主线 | `scripts/kmainline.sh <symbol>` | ~1 s | 精确短语，避免分词假阳性 |

> 伪装 User-Agent **没用**——Anubis 要跑 JS。换通道，别换 UA。

---

## 脚本

| 脚本 | 用法 | 作用 |
|---|---|---|
| `scripts/lore.py msg <msgid\|url>` | `python3 scripts/lore.py msg as6vBoWQGglxXxb0@thinkstation` | 邮件头 + 正文 |
| `scripts/lore.py thread <msgid>` | 同上 | 回复树（时间 / 深度 / 作者 / msgid） |
| `scripts/patchew.py search "<kw>"` | `python3 scripts/patchew.py search "folio references"` | 搜 series |
| `scripts/patchew.py series <cover-id>` | | diffstat + cover letter + 全部 patch |
| `scripts/kbranch.sh <repo> <branch> [n]` | `scripts/kbranch.sh .../torvalds/linux.git rcu-free-v3 8` | ls-remote + GitHub API |
| `scripts/kbranch.sh --git <repo> <branch> [n]` | | 浅克隆（慢，侧分支用） |
| `scripts/kbranch.sh --list <repo> '<pattern>'` | `--list <repo> 'refs/heads/*rcu*'` | 列分支 |
| `scripts/kmainline.sh <symbol>` | `scripts/kmainline.sh PG_rcu_free` | 是否进 mainline |
| `scripts/selftest.sh` | `bash scripts/selftest.sh` | 离线包自检 |
| `scripts/smoke.sh` | `bash scripts/smoke.sh` | 实测五条通道是否还活着 |

依赖：`curl`、`python3`、`git`。脚本**全部只读**，不会写远端。
需要能访问 `lore.kernel.org`、`patchew.org`、`marc.info`、`git.kernel.org`、
`api.github.com`；默认禁网的沙箱要先放开网络。

没有 token 时 GitHub 限额很紧：**search** API 免认证是每分钟 10 次，core API
是每小时 60 次。设置 `GITHUB_TOKEN` 后分别提升到每分钟 30 次、每小时 5000 次。

---

## 目录结构

```
kernel-lore-hunter/
├── SKILL.md                   # 技能本体：SOP + 通道矩阵 + 输出模板
├── references/                # 按需加载，启动时不读
│   ├── channels.md            # 全部 URL / API 模板
│   ├── message-id.md          # 从 Message-ID 解出作者、系列版本、RFC 阶段
│   ├── troubleshooting.md     # 现象 → 原因 → 处置
│   └── worked-example.md      # 一篇完整的文章 → patchset 全流程
├── scripts/                   # 五通道工具
├── install.sh                 # 多 agent 安装脚本
├── uninstall.sh
└── .claude-plugin/            # Claude Code 插件 / marketplace 清单
```

`SKILL.md` 刻意保持精简：agent 启动时只读 frontmatter，技能真正被触发时才读正文，
再按需读 `references/` 里对应的那一份速查。

---

## 参与贡献

Issue 和 PR 都欢迎——见 [CONTRIBUTING.md](./CONTRIBUTING.md)。
改动的门槛只有一条：**必须有你真正跑过的东西作为依据。**

```bash
bash scripts/selftest.sh
```

---

## 协议

[MIT](./LICENSE) © 2026 Wenyu Liu
