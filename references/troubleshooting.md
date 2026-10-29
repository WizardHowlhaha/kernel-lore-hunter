# 故障处置 · 现象 → 原因 → 对策

全部是实测踩过的。按现象查。

## 网络与反爬

| 现象 | 原因 | 对策 |
|---|---|---|
| `403 Forbidden` / body ~1.1 KB | Anubis 拦截 | 换 jina / marc / patchew，**别试图伪装 UA** |
| body 以 `LF git repositories` 开头 | 同上（cgit 的 Anubis 页） | 改用 git 协议 `ls-remote` / `fetch` |
| 含 `Anubis could not load its JavaScript` | 同上 | 同上 |
| jina 返回 `LF git repositories` | jina 免费额度被限流（连续十几次就会） | 等 1–2 分钟；或直接走 marc（`lore.py` 已自动回退） |
| curl 报 `Could not resolve host` | 沙箱禁网 | 显式放开网络后再跑脚本 |

## 索引与检索

| 现象 | 原因 | 对策 |
|---|---|---|
| marc `?i=` 只列出几条 | 同封邮件跨 3 个列表交叉投递 | 跟一层 `?l=...&m=...` 链接（`lore.py` 已处理） |
| patchew 搜不到 | 它只索引**收到过**的 patch 邮件 | 改用 lore thread / marc 搜索 |
| patchew 有 series 但没有 review 回复 | review 不在 patchew | 去 lore 的 thread |
| `lore.py thread` 行数比预期少 | 有些回复只在 linux-mm、不在 linux-kernel | 用 marc 跨列表搜索补全 |
| 搜出来全是噪音 | 关键词太泛 | 换成唯一符号名或分支名（见 SKILL.md Step 1） |

## git 与 GitHub

| 现象 | 原因 | 对策 |
|---|---|---|
| GitHub API 404 | 侧分支不在镜像里（镜像只跟 master） | `--git` 浅克隆，**放后台** |
| `git fetch` 卡几分钟 | linux.git 的 pack 太大 | 后台任务；depth 别超过 20；优先用 API |
| `ls-remote` 空结果 | 分支名拼错或分支已删除 | `--list <repo> 'refs/heads/*'` 全量列一遍 |
| `kmainline.sh` 报 rate limited | search API 免认证只有每分钟 10 次 | 等一分钟，或设 `GITHUB_TOKEN`（提到 30 次/分） |

## 合并判定的边界情况

`kmainline.sh` 的 `total_count = 0` 结论可信；**非零则必须人工复核**：

| 命中类型 | 可信度 | 处置 |
|---|---|---|
| 原始 patch 的 commit（非 merge） | 高 | 直接判定「已合并」 |
| `Merge ...` 开头的 commit | **假阳性**（分词匹配） | 看正文是否真有该改动；用完整 subject 加引号重搜 |
| `Revert ...` 开头的 commit | 可能被回滚 | 确认 revert 之后有没有再合回来 |
| 只在别人的 tree 里出现 | 未进主线 | 确认是否已被 maintainer 取走（查 `[GIT PULL]`） |

交叉验证办法（慢但准）：

```bash
git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git refs/heads/master
git fetch --depth=500 origin master && git log --oneline | grep -i '<symbol>'
```

## 判定「已合并」的四种可靠信号

1. `torvalds/linux` 的 master 上有该 commit（`git log` 命中）
2. lore 上出现 `[GIT PULL]` 系列的 pull request，且后面有 Linus 的 `Pulled` 回执
3. 对应 maintainer tree 里已有该 patch（如 `willy/linux` 的 mm tree）
4. `kmainline.sh` 命中**非 merge** 的原始 commit

## 判定「RFC 讨论中」

- lore thread 里有 reviewer 明确说 "Looks good, please send a formal version" → 已过审，等作者发 `[PATCH v1]`
- 只有 "please rebase" / "nit:" / "I don't like this API" → 还在讨论
- 作者已发 `[PATCH vN]` 但 review 未收敛 → 状态是「正式投稿，待 maintainer 取」

## 判定「被新版本取代」

- 同一话题存在 v1 → v2 → v3，且 v3 的 cover letter 明确说 "supersedes v2"
- 作者在新 cover letter 里重写了大段代码 → 旧版不再是讨论基准
- 引用链接仍指向旧 msgid 时，要**同时给出新版 msgid**，否则读者会跟到废弃分支
