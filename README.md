# ieaf: IEEEXplore early access follower

一个python自动化脚本，用于追踪[IEEEXplore](https://ieeexplore.ieee.org)上的期刊的early access条目。[`ieaf`](https://github.com/bufbrane/ieaf/blob/main/ieaf)即为可执行文件。

本脚本服务于如下的工作流：

0. IEEEXplore通常会在每周二至周六的夜里（0:00~8:00 UTC+08:00，下同）挂出已录用论文的early access；
1. 每天早上运行本脚本抓取early access条目（本脚本会将其存入数据库），列出未读的论文标题和对应的URL，然后基于论文标题进行初步筛选；
2. 对于感兴趣的论文标题，点击URL跳转到浏览器阅读摘要，进行进一步的筛选；阅读完摘要后如果觉得有必要阅读全文，再用文献管理软件将其下载（推荐以日期创建分类）以备后续阅读；
3. 筛选完毕，将上述论文标记为已读；标记为已读的论文在下次抓取时不再作为未读论文被列出，如此便实现了对每天上新的early access的追踪。

上述流程类似于RSS订阅，又或者说这也是本项目的主要动机：IEEEXplore的early access并没有提供官方的RSS订阅渠道（当然你可能会反驳，明明IEEEXplore官方提供了RSS源啊，莫不是在造轮子？作者的解释是，那个RSS源提供的内容来自**current issue**，并非early access），因此本脚本需要自行抓取early access。本脚本实现了类似于社交媒体的阅读机制（例如刷微博），用户可以follow自己感兴趣的期刊，每本期刊会不定时地发布最新的early access文章，利用本脚本将其汇集起来展示给用户浏览和筛选，浏览过的则不再展示。


## 运行方法：

### 自动挡：

```bash
docker run -it bufbrane/ieaf bash
xvfb-run ./ieaf -lv
./ieaf -nr
```


### 手动挡：

1. 安装第三方python库`selenium`以及软件包`chromium-driver`和`chromium`，以Debian为例：
    ```bash
    sudo apt-get install -y python3-selenium chromium-driver chromium
    ```
    一般而言，在Debian上用apt安装`python3-selenium`包时会同时安装（包括但不限于）`chromium-driver`和`chromium`这两个依赖包；
    如果所用的Linux发行版未提供后二者，或是缺乏root权限无法安装后二者，或是使用PyPI源安装`selenium`不包括后二者，或是在Windows上缺乏包管理器和软件源无法用一行命令安装后二者，
    则可以使用以下方式手动安装：
    
    1. 下载对应平台且**版本号相同**的chrome和chromedriver：[https://googlechromelabs.github.io/chrome-for-testing/](https://googlechromelabs.github.io/chrome-for-testing/)，并分别解压；
    2. 将chrome所在的**目录**添加到`PATH`环境变量，或是通过`--chrome-path`命令行参数传入该目录；
    3. 将chromedriver这个**可执行文件**复制（或软链接）到chrome所在的目录中，或是通过`--chromedriver`命令行参数传入该可执行文件的路径；
2. 本脚本需要在GUI系统中运行（例如Windows，或是有桌面环境的Linux）；

    Linux非GUI用户可以用Xvfb模拟GUI，需要安装软件包`xvfb`然后用`xvfb-run`命令运行本脚本，以Debian为例：
    ```bash
    sudo apt-get install -y xvfb
    xvfb-run ./ieaf -lv
    ./ieaf -nr
    ```
    如果你不想被频繁弹出的浏览器窗口打断工作，也可以使用这一方式运行本脚本，Windows用户也可以在WSL2中使用这一方式运行本脚本。
3. （可选）通过`--database`命令行参数传入**数据库文件**的路径；如未指定数据库文件，则默认使用`$PWD/ieaf.db`。


## 功能简介：

服务于上文提到的工作流程，ieaf脚本运行时首先会**默认**抓取（命令行参数`-n`可以跳过抓取过程）每本期刊的early access页面的所有文章条目；使用命令行参数`-v`可以显示抓取进度。

使用命令行参数`-l`（通常与`-n`合用，即`-nl`）可以列出所有未读的条目；命令行参数`-r`（通常与`-n`合用，即`-nr`）可以将所有未读的条目设置为已读。

命令行参数`-h`可以获取帮助信息。更多细节详见源代码`main()`方法。


## 抓取原理：

使用selenium库，通过chromedriver控制chrome加载和渲染网页，然后从最终呈现的HTML中提取所需的数据。

之所以使用上述技术路线而非普通的爬虫库，是因为所需的数据是JS动态加载的，而IEEEXplore网站存在较多的反爬虫措施，本脚本的作者也不愿意花太多精力去应对这些反爬虫措施，于是选择大力出奇迹。

缺点是，本脚本只能在GUI环境中运行（创建的chrome进程必须是GUI进程，`--headless`模式抓不到数据），且每抓一个网页要耗费十多秒，以及运行一个完整的浏览器内核需要几百MB内存。

上述约束条件使得本脚本只适合抓取少量期刊（比如源代码的`Ieaf.__init_database()`方法中仅预置了20本期刊）；考虑到IEEEXplore在国内的访问速度并不快，因此本脚本不打算通过并行方式加速爬取过程（以及访问频率过高也会带来其他影响，见后文）；不过，（在经费充足的条件下）计算机可以无限堆算力，但是人的时间精力就这么多，数据抓得再多，你看得完么？

本脚本与selenium库并非强耦合；可以override`Ieaf._fetch_early_access_items()`以实现新的抓取方法。


## 数据库设计：

数据库包含两张表`serials`和`items`，分别用于记录期刊信息和论文信息；表结构详见源代码中`Ieaf.__init_database()`方法内置的数据库初始化SQL脚本。

- `items.document_id`字段唯一地定义了一篇论文，取自论文页面的URL（例如 https://ieeexplore.ieee.org/abstract/document/4357009 ）；
- `serials.isnumber`字段唯一地定义了一本期刊，取自期刊的early access页面的URL（例如 https://ieeexplore.ieee.org/xpl/tocresult.jsp?isnumber=5594698 ）；
- `serials.user_defined_level`字段用于存储用户自定义的期刊优先级（数字越小优先级越高），本脚本内预置的期刊的自定义规则如下：
    - 中国计算机学会（CCF）推荐A/B/C类国际英文期刊分别对应1~3级；
    - SCI一区和二区（SCI分区使用中科院分区标准，下同）收录的国际期刊（不包括 IEEE Access）、IEEE Transactions期刊、IEEE Journal期刊对应4级；
    - SCI三区收录的国际期刊、IEEE Letters期刊对应5级；
    
    如果上述自定义规则与某高校博士研究生申请博士学位的论文成果分档标准雷同，纯属此地无银三百两。
- `serials.abbreviation`字段用于存储期刊的缩略名，本脚本内预置的期刊的1~3级采用CCF推荐的缩写，其余采用DOI缩写；

如需跟踪其他期刊或是删除上述预置期刊，请直接在数据库的`serials`表上做增删操作（该功能不常用，作者懒得在脚本中实现），例如可以使用[SQLiteStudio](https://github.com/pawelsalawa/sqlitestudio)对`serials`表进行增删操作。


## Tips:

由于网页加载的耗时是动态变化的，如果在抓取过程中网页加载超时导致报错，可以尝试再次运行本脚本。事实上本脚本的每个命令行参数对应的操作都满足幂等性，这意味着如果脚本运行出现异常时可以再次尝试运行而不破坏运行结果的一致性。如果再次尝试运行也无法解决超时问题，请先检查网络连接是否正常，然后用浏览器打开[IEEEXplore](https://ieeexplore.ieee.org)看一下网页是否正常；如果仍未解决问题，则请将脚本的报错输出提交issues。

**警告：在校园网环境中短时间内频繁使用本脚本，可能会造成校园网出口IP被IEEEXplore限流！** 考虑到这一潜在的风险，作者debug只敢在校外的网络环境中进行；作者曾有两台用于测试的校外VPS被限流（分别在境内和境外，表现为网页返回HTTP 420状态码；可见与IP归属国无关，也不是墙的问题，也不是脚本自身的问题），好在大约一周后恢复访问。虽然难以给出“短时间内”和“频繁”的精确定义，但正常使用还是没问题的；考虑到一天内多次运行并不会抓取到额外的数据，隔几天运行一次也不会漏掉数据，运行失败了再重试一次也不算多，所以“每天成功运行一次”就是正常使用的定义。

**警告：无论是机构订阅用户还是访客用户，使用本脚本抓取IEEEXplore网站的行为都会违反其[使用条款](https://ieeexplore.ieee.org/Xplorehelp/overview-of-ieee-xplore/terms-of-use)！** 作者有义务在权利方提出要求时删除本项目。理论上说本脚本还可以进一步被自动化，例如每天定时抓取，并将抓取到的内容以邮件形式发送给读者，但作者并不打算提供（至少不会开源）这样的功能。

最后，本项目以GPLv3许可证开源，这意味着不当使用本脚本所造成的任何后果（包括但不限于上述提到的校园网出口IP被限流）由使用者承担，并不会牵连到作者。不过，本脚本在设计之初就是为了满足作者本人的需求，作者本人每天也都在校园网环境中使用本脚本，而且即使在gayhub开源了也很可能除作者之外就再没有其他用户了，所以这段免责声明大概是作者的碎碎念罢（
