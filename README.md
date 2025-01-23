# ieaf: IEEEXplore early access follower

一个python自动化脚本，用于追踪[IEEEXplore](https://ieeexplore.ieee.org)上的期刊的early access条目。[`ieaf`](https://github.com/bufbrane/ieaf/blob/main/ieaf)即为可执行文件。

本脚本服务于如下的工作流：

0. IEEEXplore通常会在每周二至周六的夜里（0:00~8:00 UTC+08:00，下同）挂出已录用论文的early access；
1. 每天早上运行本脚本抓取early access条目（本脚本会将其存入数据库），列出未读的论文标题和对应的URL，然后基于论文标题进行初步筛选；
2. 对于感兴趣的论文标题，点击URL跳转到浏览器阅读摘要，进行进一步的筛选；阅读完摘要后如果觉得有必要阅读全文，再用文献管理软件将其下载（推荐以日期创建分类）以备后续阅读；
3. 筛选完毕，将上述论文标记为已读；标记为已读的论文在下次抓取时不再作为未读论文被列出，如此便实现了对每天上新的early access的追踪。


## 前置条件：


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
    xvfb-run ./ieaf
    ```
    如果你不想被频繁弹出的浏览器窗口打断工作，也可以使用这一方式运行本脚本，Windows用户也可以在WSL2中使用这一方式运行本脚本。
3. （可选）通过`--database`命令行参数传入**数据库文件**的路径；如未指定数据库文件，则默认使用`$PWD/ieaf.db`。


## 工作方式：

ieaf脚本运行时会默认抓取每本期刊的early access页面的所有文章条目，使用数据库跟踪并找出最新的未读条目；命令行参数`-n`可以跳过抓取过程。

命令行参数`-l`可以列出所有未读的条目；命令行参数`-r`（通常与`-n`合用，即`-nr`）可以将所有未读的条目设置为已读。

更多细节详见源代码`main()`方法。


## 抓取原理：

使用selenium库，通过chromedriver控制chrome加载和渲染网页，然后从最终呈现的HTML中提取所需的数据。

之所以使用上述技术路线而非普通的爬虫库，是因为所需的数据是JS动态加载的，而IEEEXplore网站存在较多的反爬虫措施，本脚本的作者也不愿意花太多精力去应对这些反爬虫措施，于是选择大力出奇迹。

缺点是，本脚本只能在GUI环境中运行（创建的chrome进程必须是GUI进程，`--headless`模式抓不到数据），且每抓一个网页要耗费十多秒，以及运行一个完整的浏览器内核需要几百MB内存。

上述约束条件使得本脚本只适合抓取少量期刊（比如源代码的`Ieaf.__init_database()`方法中仅预置了20本期刊）；考虑到IEEEXplore在国内的访问速度并不快，因此本脚本不打算通过并行方式加速爬取过程；不过，（在经费充足的条件下）计算机可以无限堆算力，但是人的时间精力就这么多，数据抓得再多，你看得完么？

本脚本与selenium库并非强耦合；可以参考`Ieaf.__fetch_early_access_items_by_selenium()`方法的接口实现新方法来抓取，然后修改`Ieaf.__fetch_early_access_items()`调用新方法。


## 数据库设计：

数据库包含两张表`serials`和`items`，分别用于记录期刊信息和论文信息；表结构详见源代码中`Ieaf.__init_database()`方法内置的数据库初始化SQL脚本。

- `items.document_id`字段唯一地定义了一篇论文，取自论文页面的URL（例如 https://ieeexplore.ieee.org/abstract/document/4357009 ）；
- `serials.isnumber`字段唯一地定义了一本期刊，取自期刊的early access页面的URL（例如 https://ieeexplore.ieee.org/xpl/tocresult.jsp?isnumber=5594698 ）；
- `serials.user_sorted_order`字段用于存储用户自定义的期刊优先级（数字越小优先级越高），本脚本内预置的期刊的自定义规则如下：
    - 中国计算机学会（CCF）推荐A/B/C类国际英文期刊分别对应1~3级；
    - SCI一区和二区（SCI分区使用中科院分区标准，下同）收录的国际期刊（不包括 IEEE Access）、IEEE Transactions期刊、IEEE Journal期刊对应4级；
    - SCI三区收录的国际期刊、IEEE Letters期刊对应5级；
    
    如果上述自定义规则与某高校博士研究生申请博士学位的论文成果分档标准雷同，纯属此地无银三百两。
- `serials.abbreviation`字段用于存储期刊的缩略名，本脚本内预置的期刊的1~3级采用CCF推荐的缩写，其余采用DOI缩写；

如需跟踪其他期刊或是删除上述预置期刊，请直接在数据库的`serials`表上做增删操作（该功能不常用，作者懒得在脚本中实现，也不愿意将与serials相关的操作改为public方法），例如可以使用[SQLiteStudio](https://github.com/pawelsalawa/sqlitestudio)对`serials`表进行增删操作。


## Tips:

由于网页加载的耗时是动态变化的，如果在抓取过程中网页加载超时导致报错，可以尝试再次运行本脚本。

事实上本脚本的每个命令行参数对应的操作都满足幂等性，这意味着如果脚本运行出现异常时可以再次尝试运行而不破坏运行结果的一致性。如果多次尝试都无法解决超时问题，请先检查网络连接是否正常，然后将报错输出提交issues。
