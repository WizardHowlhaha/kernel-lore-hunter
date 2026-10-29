---
name: kernel-lore-hunter
description: 追踪 Linux 内核补丁与讨论——从一篇文章、一个 commit、一个分支名、一个符号名或一个话题出发，定位对应的 patchset、LKML/linux-mm/linux-fsdevel 邮件串、维护者 git 分支，并判断版本与是否已合并。Use when the user gives an article, commit hash, branch name, kernel symbol (e.g. PG_rcu_free, filemap_read_rcu_batch) or topic and asks for "the patchset", "the LKML/lore thread", "who sent it", "is it merged", or "where is the review discussion"; also for a series' review feedback, who took over a series, or whether a feature reached mainline. Works around the Anubis bot-wall on lore.kernel.org / git.kernel.org / lkml.org via r.jina.ai, marc.info, patchew.org, the git protocol and the GitHub mirror API.
license: MIT
compatibility: Needs python3, curl and git on PATH plus outbound access to lore.kernel.org, patchew.org, marc.info, git.kernel.org and api.github.com. Network-disabled sandboxes must enable network before running the scripts.
metadata:
  author: WizardHowlhaha
  version: 1.0.0
  keywords: linux-kernel, lkml, lore, patch, patchset, mm, folio, rcu, mainline, anubis
allowed-tools: Bash, Read, Grep, Glob, WebFetch, WebSearch
---

# Kernel Lore Hunter

目标：把「一篇文章 / 一个 commit / 一句现象」在 10 分钟内还原成 **代码分支 + 邮件讨论 + 版本状态** 三件套，且每条结论都有可点击的永久链接。

> **文件分工**：本文件是执行主文件（SOP + 通道矩阵 + 输出模板）。速查表按需再查，别一次性全读：
>
> | 要查什么 | 去哪 |
> |---|---|
> | lore / patchew / marc / git / GitHub 镜像的全部 URL 模板 | `references/channels.md` |
> | 从 Message-ID 反推作者、系列版本、RFC 编号 | `references/message-id.md` |
> | 报错现象 → 原因 → 处置；合并判定的边界情况 | `references/troubleshooting.md` |
> | 一篇完整文章的排查全过程（含最终报告样例） | `references/worked-example.md` |

## 0. 何时使用

- 用户贴一篇文章（尤其微信公众号、科技媒体）说「帮我找里面的 kernel patchset 和讨论」
- 用户给一个 commit hash / 分支名 / 内核符号，问「这是谁提的、讨论在哪、合了没」
- 需要查某个 patch 的 review 意见（谁反对、理由、后来怎么改的）
- 需要判断某功能是否已进 mainline，或停在 RFC v几

## 1. 先记住三条现实

1. **lore.kernel.org / git.kernel.org / lkml.org 全站挂在 Anubis（JS 工作量证明反爬）后面。** 直接 `curl` 得到 `403` 或一个约 1.1 KB、以 `LF git repositories` / `Making sure you're not a bot` / `Loading...` 开头的**假页面**。伪装 UA 无效——它要跑 JS。
2. **五条通道可用**：`r.jina.ai`（读 lore，会被限流）、`marc.info`（最稳、无 JS）、`patchew.org`（series 专用）、**git 协议**（`ls-remote`/`fetch`，完全绕过 Anubis）、**GitHub 镜像 API**（读 master 上的 commit，秒级）。
3. **二手文章几乎必有三处错**：日期、补丁数量、分支归属。以 lore 原文和 `git log` 为准。

## 2. 通道矩阵（含实测耗时）

| 需求 | 用什么 | 耗时 | 说明 |
|---|---|---|---|
| 读某一封邮件 | `scripts/lore.py msg <msgid>` | ~3 s | jina 优先，含头信息与正文 |
| 同上但 jina 被限流 | 自动回落 marc.info | ~2 s | 无 thread 视图 |
| 看回复树（谁回谁） | `scripts/lore.py thread <msgid>` | ~3 s | 只有 jina 提供，被限流就等 1–2 分钟 |
| 找 series / 逐 patch | `scripts/patchew.py search` / `series` | ~2 s | 有 cover letter、diffstat、全部 patch |
| 确认分支存在 | `git ls-remote --heads <repo> 'refs/heads/*kw*'` | ~1 s | **先做这一步**，比任何网页都快 |
| 读 master 上的 commit | `scripts/kbranch.sh <repo> master N` | ~2 s | 走 GitHub API |
| 读侧分支的 commit | `scripts/kbranch.sh --git ...` | **3–5 min** | linux.git pack 巨大，必须后台跑 |
| 按月考古 | `https://lkml.iu.edu/hypermail/linux/kernel/YYMM.N/` | 数秒 | MHonArc 静态归档 |
| 判断是否进主线 | `scripts/kmainline.sh <symbol>` | ~1 s | 精确短语，避免分词假阳性 |

全部脚本只读，且**不依赖 skill 的安装位置**——用绝对路径调用即可：

```bash
python3 /path/to/kernel-lore-hunter/scripts/lore.py msg <msgid>
```

## 3. 标准作业流程（SOP）

**Step 1 · 提纯关键词。** 只取独一无二的串：函数名 `filemap_read_rcu_batch`、页标志 `PG_rcu_free`、分支名 `noref-filemap-read-with-llm`。不要用 `page cache performance` 这种泛词，搜出来全是噪音。

**Step 2 · 搜网定位。** 一次发 2–4 条 `web_search`（符号名 / 分支名 / 人名+主题 / 文章标题各一条）。目标是拿到 **message-id、series 名或分支名** 中任意一个。结果里的 `lkml.org/lkml/YYYY/MM/DD/NNN`、`patchew.org/...`、`lore.kernel.org/all/<msgid>/` 都是入口。

**Step 3 · git 侧压实（快，先做）。**

```bash
git ls-remote --heads https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git 'refs/heads/*rcu*'
```

命中后：master 上的 commit 用 `kbranch.sh`（GitHub API，秒级）；**侧分支直接读 cover letter**——它通常就是分支 tip，而且 Linus 习惯放一个**空提交**当 cover letter：

```bash
git show --stat <tip>      # 空 → 这就是 cover letter 提交
```

**Step 4 · 读 cover letter 原文。** 重点读：Problem / Idea / Numbers / Known problems / Tools（有没有 "LLM coding assistant" 声明）/ 末尾的 `[1] [2] ...` 参考链接——那通常就是整个前史链条。

**Step 5 · 展开 thread。** 用 `lore.py thread` 拿到回复树，挑三种人细读：**原始作者**、**子系统维护者**（willy / hch / david / akpm / hughd）、**提出反对意见的人**。用 `msg` 逐条抓，别只看标题。

**Step 6 · 找后续版本。** 同一话题常有 v2/v3/"RFC 00/18" 重写版：patchew 搜同一关键词；lore 串往后翻；作者的 tree 常有 `feature/rfc-v1`、`feature/clean` 之类分支。

**Step 7 · 判定状态并写清抓取日期。** 结论只有三种：`已合并` / `RFC 讨论中` / `被新版本取代`。拿不准就写「截至 YYYY-MM-DD 未见合并」。

## 4. 判断「是否已合并」

```bash
scripts/kmainline.sh PG_rcu_free
```

- `total_count = 0` → 未合并（可信）
- 命中 merge commit → **假阳性**：GitHub 按词切分，merge 正文含关键词也会被召回；用完整 subject 加引号，或加 `+author:` 复核
- 最稳但最慢：`ls-remote master` 取 tip，`fetch --depth=500` 后 `git log | grep -i <symbol>`（后台跑）

边界情况（何时不能只看 `kmainline.sh`）见 `references/troubleshooting.md`。

## 5. 附带脚本

| 脚本 | 用法 | 作用 |
|---|---|---|
| `scripts/lore.py msg <msgid\|url>` | `python3 scripts/lore.py msg as6vBoWQGglxXxb0@thinkstation` | jina 优先，自动检测 Anubis 并回落 marc；含 marc 索引页二次跳转 |
| `scripts/lore.py thread <msgid>` | 同上 | 打印回复树（时间 / 深度 / 作者 / msgid） |
| `scripts/patchew.py search "<kw>"` | `python3 scripts/patchew.py search "folio references"` | 搜 series，列 cover-id |
| `scripts/patchew.py series <cover-id>` | | diffstat + cover letter + 全部 patch 链接 |
| `scripts/kbranch.sh <repo> <branch> [n]` | `scripts/kbranch.sh .../torvalds/linux.git rcu-free-v3 8` | ls-remote + GitHub API（秒级） |
| `scripts/kbranch.sh --git <repo> <branch> [n]` | | 浅克隆（慢，侧分支用） |
| `scripts/kbranch.sh --list <repo> '<pattern>'` | `--list <repo> 'refs/heads/*rcu*'` | 列分支，1 秒 |
| `scripts/kmainline.sh <symbol>` | `scripts/kmainline.sh PG_rcu_free` | 是否进 mainline |
| `scripts/selftest.sh` | `bash scripts/selftest.sh` | 离线自检（不联网），安装后验证用 |
| `scripts/smoke.sh` | `bash scripts/smoke.sh` | 实测各通道是否还活着（会联网） |

依赖：`curl`、`python3`、`git`。全部只读。

> **网络**：脚本要访问 lore.kernel.org / patchew.org / marc.info / api.github.com。
> 在 Codex 这类默认禁网的沙箱里运行时，必须显式放开网络，否则 `curl` 直接失败。

## 6. 输出模板

先给一句结论（这是什么、谁做的、什么状态），再分块：

```markdown
## 1. 代码 / patchset
| 对象 | 链接 | 说明 |
（分支 · 关键 commit · 每版 series）

## 2. 讨论主线
| 时间 | 人 | 观点 | 链接 |
（根邮件 + 3–6 封关键 review）

## 3. 前史 / 相关尝试
（同一问题的历次 series，按时间排）

## 4. 与文章不一致处
（日期、计数、归属，逐条列）

## 5. 状态
截至 YYYY-MM-DD：RFC / 已合并 / 被取代
```

链接一律给 **`/all/<msgid>/` 永久地址**，不要给 `?q=` 搜索结果页。引用时注明「lore.kernel.org」。

完整样例见 `references/worked-example.md`。
