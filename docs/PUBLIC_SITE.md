# TurnCue 公开页面

沿用 shouxia 的 `docs/` 静态站点结构，使用 TurnCue 的“城市旧图册”品牌。页面无 JavaScript、无构建依赖、无外部字体或统计脚本。

## 文件与计划地址

| 内容 | 文件 | 计划地址 |
| --- | --- | --- |
| 首页 | `docs/index.html` | https://xiaomao361.github.io/turncue/ |
| 使用说明 | `docs/guide/index.html` | https://xiaomao361.github.io/turncue/guide/ |
| 隐私政策 | `docs/privacy/index.html` | https://xiaomao361.github.io/turncue/privacy/ |
| 支持与 FAQ | `docs/support/index.html` | https://xiaomao361.github.io/turncue/support/ |
| 版本记录 | `docs/changelog/index.html` | https://xiaomao361.github.io/turncue/changelog/ |

公共样式为 `docs/assets/site.css`，图标取自当前应用 AppIcon，导航复用 `docs/brand/turncue-logo-lockup.svg`。当前无真实截图素材，因此首页只展示品牌图标，不模拟应用运行画面。

项目远端为 `https://github.com/xiaomao361/turncue.git`，代码使用 `main` 分支。代码推送与 GitHub Pages 部署是两个独立步骤；上表为计划地址，不是上线证明。

## 本地检查

在仓库根目录运行：

```sh
python3 scripts/check_site.py
python3 -m http.server 8080 --directory docs
```

第二条命令仅启动本地服务，可自行访问 `http://localhost:8080/`。检查导航、FAQ 展开、邮件链接、键盘跳过导航，以及 375px 手机宽度和桌面宽度的布局。

`check_site.py` 检查本地链接与锚点、图片替代文本、标题、语言、基础 SEO 和站点地图。它不证明浏览器视觉、外部链接可达性、真实收信能力或线上部署完成。

## 发布方式

站点文件随项目提交到 `main`。后续发布时，按 [GitHub Pages 官方说明](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)，设置来源为分支 `main` 的 `/docs` 目录；该操作需在发布任务中完成。`.nojekyll` 用于直接提供静态文件。

注意：这种来源会发布整个 `docs/`，包括其中的品牌探索素材、MVP 文档和上架草稿。上传前检查目录内没有私人路线、用户截图、凭据或其他不适合公开的内容。如果需要严格限定发布文件，再改为仅打包五个页面、`assets/`、所需品牌文件和 `sitemap.xml` 的独立工作流。

部署后逐一验证五个页面、样式和图标返回正常，再填写 App Store 的营销、支持和隐私网址。仓库内的 `sitemap.xml` 仅覆盖公开产品页面；不为项目子路径添加无效的根域 `robots.txt`。

## 内容依据与维护

- 能力和版本：当前 Swift 源码、README、工程 `MARKETING_VERSION = 0.4` / `CURRENT_PROJECT_VERSION = 4`。
- 样式与结构参考：shouxia 当前公开首页、隐私与支持页面；不复制下载或产品能力承诺。
- 支持邮箱：沿用 shouxia 的开发者公开地址 `zhouwei@linux.com`；没有发送邮件或验证收件。
- 地图隐私：[Apple 地图与隐私](https://www.apple.com/legal/privacy/data/en/apple-maps/)，于 2026-09-07 查阅；应用具体请求字段同时依据源码核对。
- 上架信息草稿见 [`app-store/METADATA_ZH_HANS.md`](app-store/METADATA_ZH_HANS.md)，发布前检查见 [`app-store/RELEASE_CHECKLIST.md`](app-store/RELEASE_CHECKLIST.md)。

修改功能、位置处理、存储、账号或分享行为时，同步首页、使用说明、FAQ、隐私政策、版本记录和元数据。确认正式下载渠道前，保留“下载渠道尚未公布”，不使用占位下载按钮。未来上架日期应以实际发布为准，不使用文档日期替代。
