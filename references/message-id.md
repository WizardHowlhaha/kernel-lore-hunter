# 从 Message-ID 反推作者与版本

kernel 邮件的 Message-ID 几乎总是带信息。这是快速判断「谁提的、这是第几版」的最省事办法。

## 已知模式

| Message-ID 形态 | 含义 |
|---|---|
| `CAHk-=w...@mail.gmail.com` | **Linus Torvalds**（`CAHk-=` 前缀是他的 Arcane 签名） |
| `<YYYYMMDDhhmmss>.<n>-<m>-<user>@host` | **b4 生成的 series**（如 `20261019154913.1765974-1-kas@kernel.org`） |
| `cover.<epoch>.git.<user>@host` | b4 的 **cover letter**（不是 patch 本身） |
| `asXXXX@casper.infradead.org` | **Matthew Wilcox** |
| `...@thinkstation` | **Kiryl Shutsemau**（kas） |
| `...@kernel.org` | 多为 Arm / Red Hat / SUSE 体系维护者，需再确认 |
| `...@gmail.com` / `...@outlook.com` | 个人邮箱，作者靠 From 头或签名确认 |

## Subject 行编码的信息

| Subject 形态 | 含义 |
|---|---|
| `[RFC PATCH v3 04/18]` | RFC、第 3 版、本系列第 4/18 封 |
| `[PATCH v7 00/12]` | 非 RFC 的第 7 版，12 个 patch |
| `[PATCH 3/5]` | 第 3 封，共 5 封（可能无版本号） |
| `[GIT PULL ...]` | **已进入维护者 tree**（待 Linus 取） |
| `[GIT PULL v2 ...]` | 维护者 tree 的第二版 pull request |
| `Re: [PATCH ...]` | 讨论回复 |
| `[PATCH v2 0/7] mm: ...` | `mm:` 之类是子系统前缀，决定该发给谁 |

## 关键判断：vN 与 RFC 的区别

- `[PATCH vN ...]` 是**正式投稿**（直接进 maintainer tree → Linus 的 pull request 链）。
- `[RFC PATCH vN ...]` 是**征求意见**，reviewer 说 "Looks good, please send a formal version" 之后作者通常发 `[PATCH v1 ...]`。
- 同一话题出现 RFC → PATCH 的转换，通常意味着**已经过了审**。

## b4 series 的读法

```
20261019154913.1765974-1-kas@kernel.org
└─ 时间戳 2026-10-19 15:49:13
   └─ 进程号 .1765974
      └─ -1-    该系列第 1 封（00/18 是 cover）
         └─ kas  作者短名
```

b4 的 cover letter 是**空提交**（或只含 `--` 后的说明），在 git 里表现为 `git show --stat` 输出为空。

## 维护者前缀速查

| 前缀 | 子系统 | 常见维护者 |
|---|---|---|
| `mm:` | 内存管理 / page cache | willy, hughd, Matthew Wilcox |
| `fs:` | 文件系统 | Dave Chinner, Al Viro, xfs 团队 |
| `bpf:` | eBPF | Alexei Starovoitov, Daniel Borkmann |
| `block:` | 块层 | Jens Axboe, Tejun Heo |
| `net:` | 网络 | David Miller, Jakub Sitnicki |
| `cgroup:` | cgroup | Tejun Heo, James Morris |
| `virtio:` | virtio | Rusty Russell, Michael Tsirkin |
| `nfs:` | NFS | Trond Myklebust, Jeff Mogilich |

看到前缀基本就知道该找谁 review，也知道 patch 最终会落到哪个 tree。
