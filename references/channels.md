# 通道速查 · URLs 与 APIs

按需查阅本文件。**不要**一次性全读。

## lore.kernel.org（被 Anubis 挡，脚本/curl 会被拦，浏览器可开）

```
https://lore.kernel.org/all/<msgid>/                      单封（页面底部就是 thread overview）
https://lore.kernel.org/all/<msgid>/T/#u                  flat 视图
https://lore.kernel.org/all/<msgid>/t.mbox.gz             整串 mbox（想本地 grep 时用）
https://lore.kernel.org/all/<msgid>/raw                   原始邮件（rfc822）
https://lore.kernel.org/all/?q=<kw>                       搜索（几乎必被拦，别依赖）
https://lore.kernel.org/list/<list>/                       某个列表的线程列表
```

`<msgid>` 里含 `@` 与 `+`，在 URL 里要百分号编码（脚本已自动处理）。

## patchew.org（不被 Anubis 挡，series 首选）

```
https://patchew.org/search?q=<kw>                          搜 series
https://patchew.org/linux/<cover-msgid>/                   系列首页（diffstat + cover letter）
https://patchew.org/linux/<cover-msgid>/<patch-msgid>/     单个 patch
```

patchew 只索引**它收到过**的 patch 邮件；纯讨论邮件（review 回复）不在里面，需回 lore。

## marc.info（最稳，无 JS，有跨列表交叉投递索引）

```
https://marc.info/?i=<msgid>                              按 Message-ID 查（是索引页，正文在一层 m= 之后）
https://marc.info/?l=linux-mm&w=2&r=1&s=<kw>&q=b          正文关键词搜索
https://marc.info/?l=<list>&m=<n>&w=2                     某个列表的某封邮件正文
```

`<list>` 常见值：`linux-kernel`、`linux-mm`、`linux-fsdevel`、`linux-arm-kernel`、`linux-bcache`。

## 按月考古（MHonArc 静态归档，无反爬）

```
https://lkml.iu.edu/hypermail/linux/kernel/YYMM.N/       e.g. 2610.N
https://lkml.iu.edu/hypermail/linux/mm/YYMM.N/
```

适合「只知道大致月份 + 主题关键词」的场合；缺点是没有回复树。

## git（完全绕过 Anubis）

```
git ls-remote --heads <repo> 'refs/heads/*<kw>*'          列分支，1 秒
git ls-remote <repo> 'refs/heads/master'                  取 master tip
git fetch --depth=<N> origin refs/heads/<branch>          浅克隆侧分支（后台跑）
```

常用仓库：

| 仓库 | URL |
|---|---|
| Linus | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git` |
| mm | `https://git.kernel.org/pub/scm/linux/kernel/git/willy/linux.git` |
| Kiryl | `https://git.kernel.org/pub/scm/linux/kernel/git/kas/linux.git` |
| hch | `https://git.kernel.org/pub/scm/linux/kernel/git/hch/linux.git` |
| Andrew Morton | `https://git.kernel.org/pub/scm/linux/kernel/git/akpm/linux.git` |

cgit web log 页面被 Anubis 挡，但 **git 协议不受影响**——这是最可靠的通道。

## GitHub 镜像（快，但只有 master 的对象）

```
https://api.github.com/repos/torvalds/linux/commits/<sha>
https://api.github.com/search/commits?q=repo:torvalds/linux+%22<exact phrase>%22
```

- 侧分支**不在**镜像里（镜像只跟 master），搜不到不等于不存在。
- `search/commits` 会**分词**，merge commit 正文提到关键词也会命中 → 见 `troubleshooting.md`。
- 免认证的 **search** API 只有每分钟 10 次（core API 每小时 60 次）；带 `GITHUB_TOKEN` 后分别是每分钟 30 次、每小时 5000 次：

```bash
curl -sG -H "Authorization: Bearer $GITHUB_TOKEN" \
  --data-urlencode 'q=repo:torvalds/linux "PG_rcu_free"' \
  https://api.github.com/search/commits
```

## 其他值得知道的镜像

```
https://git.zx2c4.com/                    # b4 / git-annex 作者（Jonathan Corgan? 实际为 zx2c4 = Drew DeVault's 镜像站）
https://kernel.googlesource.com/          # Google 官方镜像，含各子系统维护者 tree
```

`kernel.googlesource.com` 的 git 协议同样绕过 Anubis，且有部分维护者的独立 tree。

## 反爬识别特征

Anubis 拦截页的特征（出现任意一条即视为被拦）：

- HTTP 状态 `403`
- body 长度约 1.1 KB
- 以 `LF git repositories` / `Making sure you're not a bot` / `Loading...` 开头
- 含 `Anubis could not load its JavaScript`

**伪装 User-Agent 无效**——Anubis 要跑 JS 求解工作量证明。换通道，别换 UA。
