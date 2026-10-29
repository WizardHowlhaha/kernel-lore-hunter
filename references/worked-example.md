# 完整样例 · 从一篇文章追到 patchset

这个样例展示**完整排查链条**，包含最常见的错误类型（文章与事实不符）。可当 few-shot 参考。

## 输入

> 「这篇讲 Linus 用 Claude Code 改 page cache 的文章，找出相关 patchset。」
> （链接指向一篇科技媒体文章）

## 排查过程

### Step 1 · 提纯关键词

文章里能直接用的唯一串：

- 函数名 `filemap_read_rcu_batch`
- 页标志 `PG_rcu_free`
- 分支名 `noref-filemap-read-with-llm`
- 人名：Linus、Kiryl Shutsemau、Matthew Wilcox

**丢弃**：「page cache 性能优化」「LLM 写内核」这类泛词——搜出来全是无关内容。

### Step 2 · 搜网定位

4 条 `web_search`：符号名 / 分支名 / 人名+主题 / 文章标题。

拿到的入口：

- `lore.kernel.org/all/CAHk-=wjLjgfwgSZ1RDk4YdNFcV0ntosMO5AmBoHD76Zb3HFY7Q@mail.gmail.com/`
- `patchew.org/linux/20261019154913.1765974-1-kas@kernel.org/`

### Step 3 · git 侧压实（快，先做）

```bash
git ls-remote --heads https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git 'refs/heads/*rcu*'
# 8a1f3c9d...  refs/heads/noref-filemap-read-with-llm
# c42b7e05...  refs/heads/rcu-free-v3
```

分支命中。master 上的 commit 走 `kbranch.sh`（GitHub API，秒级）；侧分支读 cover letter——Linus 习惯放一个**空提交**当 cover letter。

### Step 4 · 读 cover letter 原文

重点段落：Problem（folio 替换要拿 i_size 锁）/ Numbers（benchmark 提升）/ Known problems（并发写者）/ Tools（**"LLM coding assistant" 声明**）/ 末尾 `[1] [2]` 参考链接。

`[1]` 指向 Kiryl 更早的实验，`[2]` 指向 Matthew 的反对意见——**这两条链接基本就是整个前史链条**。

### Step 5 · 展开 thread

`lore.py thread` 拿到 24 封回复。挑三类人细读：

| 人 | 角色 | 关键点 |
|---|---|---|
| Linus | 原始作者 | 起 series，当场交给 Kiryl 重写 |
| Matthew Wilcox | 子系统维护者 | **反对 `PG_rcu_free` 页标志**（页标志空间紧张） |
| Kiryl Shutsemau | 重写者 | 指出 `filemap_read_rcu_batch()` 的 folio 替换 + i_size 扩展竞态 |

### Step 6 · 找后续版本

patchew 搜同一关键词 → 找到 `[RFC PATCH 00/18]` 重写版（b4 生成，`cover.` 前缀）。

### Step 7 · 判定状态

```bash
bash scripts/kmainline.sh PG_rcu_free
# total_count = 0
# => not in mainline (as of the mirror tip)
```

## 最终产出骨架

- **代码**：`torvalds/linux` 的 `noref-filemap-read-with-llm`（8 patch + 1 空 cover，2026-10-07~10）与 `rcu-free-v3`；Kiryl 的重写在 `kas/linux` 的 `rcu-free/rfc-v1`
- **讨论根**：[Improve page refcount scalability](https://lore.kernel.org/all/CAHk-=wjLjgfwgSZ1RDk4YdNFcV0ntosMO5AmBoHD76Zb3HFY7Q@mail.gmail.com/)（2026-10-13，24 封回复）
- **关键 review**：
  - Matthew 反对 `PG_rcu_free` 页标志（`as6ckC9NJVB8JBuV`）
  - Kiryl 指出 `filemap_read_rcu_batch()` 的 folio 替换 + i_size 扩展竞态（`as6vBoWQGglxXxb0`）
  - Linus 当场把系列交给 Kiryl（`CAHk-=wiCe2H33iz…`）
- **重写版**：[RFC PATCH 00/18](https://lore.kernel.org/all/20261019154913.1765974-1-kas@kernel.org/)（2026-10-19）
- **状态**：截至 2026-10-29 未进 mainline（`kmainline.sh PG_rcu_free` → 0）
- **校正**：文章「10 月 11 日推送」「2024 年底提出」「rcu-free-v3 是 Kiryl 重写」三处不准确

## 三类典型文章错误

| 错误类型 | 表现 | 校正方式 |
|---|---|---|
| **日期错位** | 文章说「10 月 11 日推送」，实际是 10 月 7 日开 series、13 日发讨论 | 以 lore 的 `Date:` 头和 cover letter 为准 |
| **补丁数量错** | 文章说「3 个补丁」，实际 series 有 8 个 patch + 1 个 cover | 数 `git log` / patchew 的 patches 列表 |
| **分支归属错** | 文章说「rcu-free-v3 是 Kiryl 的重写」，实际那是 Linus tree 上的分支 | 用 `git ls-remote` 逐个确认仓库归属 |

## 交付前自查

- [ ] 每条结论都有 `/all/<msgid>/` 永久链接，不是搜索结果页
- [ ] 日期、人名、补丁数都从一手来源核过
- [ ] 状态标注了**抓取日期**（「截至 YYYY-MM-DD 未见合并」）
- [ ] 与原文不一致的地方**逐条列出**，而不是默默采用其中一个说法
- [ ] 区分了「未合并」与「未找到」——前者是结论，后者是检索没做到位
