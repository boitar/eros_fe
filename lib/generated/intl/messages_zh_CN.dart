// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh_CN';

  static String m0(count) => "${count} 列";

  static String m1(min, max) => "${min}–${max} 列";

  static String m2(count) => "${count} 条";

  static String m3(page) => "继续阅读 · 第 ${page} 页";

  static String m4(site) => "当前 ${site}";

  static String m5(reused) => "复用 ${reused} 页";

  static String m6(checked, found, failed) =>
      "已检测 ${checked} 部 · ${found} 部有新版（${failed} 部失败）";

  static String m7(count) => "发现 ${count} 部画廊有更新版本";

  static String m8(gid) => "源自父画廊 #${gid}";

  static String m9(count) => "${count} 人评分";

  static String m10(count) => "有 ${count} 个更新版本";

  static String m11(gid) => "当前版本 #${gid}";

  static String m12(value) => "峰值 ${value}";

  static String m13(value) => "周期均值 ${value}";

  static String m14(period, percent) => "${period} · 占比 ${percent}%";

  static String m15(value) => "周期总计 ${value}";

  static String m16(score) => "积分 ${score}";

  static String m17(date) => "${date} 修订";

  static String m18(gid, reused) => "已本地升级至 #${gid}（全部复用 ${reused} 页）";

  static String m19(gid) => "复用本地未改动原图，任务更新至 #${gid} 并自动映射阅读进度。";

  static String m20(gid) => "新建 #${gid} 目录并复用未改动图片，旧版目录保持不变。";

  static String m21(count) => "仅需拉取 ${count} 页";

  static String m22(count) => "原位增量更新 · 拉取 ${count} 页";

  static String m23(count) => "新建任务并复用 · 拉取 ${count} 页";

  static String m24(count) => "新建任务完整下载 · 拉取 ${count} 页";

  static String m25(reused, fetch) => "已启动增量更新：复用 ${reused} 页，拉取 ${fetch} 页";

  static String m26(modelName) => "模式 ${modelName}";

  static String m27(count) => "${count} 页";

  static String m28(seconds) => "${seconds} 秒";

  static String m29(page, total) => "第 ${page} 页，共 ${total} 页";

  static String m30(rating) => "${rating} ⭐";

  static String m31(tag) => "添加 ${tag}";

  static String m32(count) => "共 ${count} 页";

  static String m33(avg, count) => "均分 ${avg} · ${count} 人评分";

  static String m34(text) => "搜索 “${text}”";

  static String m35(count) => "已添加 ${count} 个 · 用逗号分隔";

  static String m36(count, per) => "共 ${count} 页 · 每页 ${per} 张";

  static String m37(count) => "种子 · ${count} 个";

  static String m38(tagNamespace) =>
      "${Intl.select(tagNamespace, {'reclass': '重新分类', 'language': '语言', 'parody': '原作', 'character': '角色', 'group': '社团', 'artist': '艺术家', 'male': '男性', 'female': '女性', 'mixed': '混杂', 'cosplayer': '扮演者', 'other': '其它', 'temp': '临时'})}";

  static String m39(version) => "可更新到 ${version}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "KEEP_IT_SAFE": MessageLookupByLibrary.simpleMessage("注意数据安全"),
    "QR_code_block": MessageLookupByLibrary.simpleMessage("屏蔽含有二维码的图片"),
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "add_quick_search": MessageLookupByLibrary.simpleMessage("添加搜索"),
    "add_tag_placeholder": MessageLookupByLibrary.simpleMessage("输入新标签, 用逗号分隔"),
    "add_tags": MessageLookupByLibrary.simpleMessage("添加标签"),
    "add_to_favorites": MessageLookupByLibrary.simpleMessage("添加收藏夹"),
    "add_to_phash_block_list": MessageLookupByLibrary.simpleMessage(
      "添加到感知哈希屏蔽列表",
    ),
    "advanced": MessageLookupByLibrary.simpleMessage("高级"),
    "aggregate": MessageLookupByLibrary.simpleMessage("聚合"),
    "aggregate_groups": MessageLookupByLibrary.simpleMessage("聚合分组"),
    "all_Favorites": MessageLookupByLibrary.simpleMessage("所有收藏"),
    "all_comment": MessageLookupByLibrary.simpleMessage("所有评论"),
    "all_thumbnails": MessageLookupByLibrary.simpleMessage("所有缩略图"),
    "allow_media_scan": MessageLookupByLibrary.simpleMessage("允许媒体扫描"),
    "always": MessageLookupByLibrary.simpleMessage("始终"),
    "app_title": MessageLookupByLibrary.simpleMessage("Eros-FE"),
    "appearance_and_layout": MessageLookupByLibrary.simpleMessage("外观与布局"),
    "ask_me": MessageLookupByLibrary.simpleMessage("询问"),
    "auth_biometricHint": MessageLookupByLibrary.simpleMessage("验证身份"),
    "auth_signInTitle": MessageLookupByLibrary.simpleMessage("需要进行身份验证"),
    "author": MessageLookupByLibrary.simpleMessage("作者"),
    "autoLock": MessageLookupByLibrary.simpleMessage("自动锁定"),
    "auto_scroll": MessageLookupByLibrary.simpleMessage("自动滚动"),
    "auto_select_profile": MessageLookupByLibrary.simpleMessage("自动选择配置"),
    "automatic": MessageLookupByLibrary.simpleMessage("自动"),
    "avatar": MessageLookupByLibrary.simpleMessage("头像"),
    "avatar_cf_verify_message": MessageLookupByLibrary.simpleMessage(
      "论坛启用了 Cloudflare 防护，请在内置浏览器中完成人机验证，完成后将自动重试上传。",
    ),
    "avatar_cf_verify_title": MessageLookupByLibrary.simpleMessage(
      "需要 Cloudflare 验证",
    ),
    "avatar_from_album": MessageLookupByLibrary.simpleMessage("相册"),
    "avatar_from_file": MessageLookupByLibrary.simpleMessage("文件"),
    "avatar_from_url": MessageLookupByLibrary.simpleMessage("图片 URL"),
    "avatar_local_success": MessageLookupByLibrary.simpleMessage("头像已更新"),
    "avatar_source": MessageLookupByLibrary.simpleMessage("选择图片来源"),
    "avatar_target": MessageLookupByLibrary.simpleMessage("将头像用在哪里？"),
    "avatar_upload_success": MessageLookupByLibrary.simpleMessage("头像已上传"),
    "avatar_use_forum": MessageLookupByLibrary.simpleMessage("上传到 EH 论坛"),
    "avatar_use_local": MessageLookupByLibrary.simpleMessage("仅本机使用"),
    "back": MessageLookupByLibrary.simpleMessage("返回"),
    "back_to_top": MessageLookupByLibrary.simpleMessage("回到顶部"),
    "block_rule": MessageLookupByLibrary.simpleMessage("屏蔽规则"),
    "block_rules": MessageLookupByLibrary.simpleMessage("屏蔽规则"),
    "blockers": MessageLookupByLibrary.simpleMessage("本地屏蔽"),
    "blurring_cover_background": MessageLookupByLibrary.simpleMessage(
      "封面背景模糊化",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "card_size": MessageLookupByLibrary.simpleMessage("卡片大小"),
    "card_size_footer": MessageLookupByLibrary.simpleMessage(
      "列数按这一栏的实际宽度计算：换屏、旋转或拖动分割条都会自动增减。「标准」与原来的自动列数相同。",
    ),
    "card_size_large": MessageLookupByLibrary.simpleMessage("大"),
    "card_size_larger": MessageLookupByLibrary.simpleMessage("较大"),
    "card_size_small": MessageLookupByLibrary.simpleMessage("小"),
    "card_size_smaller": MessageLookupByLibrary.simpleMessage("较小"),
    "card_size_standard": MessageLookupByLibrary.simpleMessage("标准"),
    "card_style": MessageLookupByLibrary.simpleMessage("卡片样式"),
    "card_style_immersive": MessageLookupByLibrary.simpleMessage("沉浸"),
    "card_style_immersive_detail": MessageLookupByLibrary.simpleMessage(
      "只显示封面，标题与评分叠在封面上",
    ),
    "card_style_standard": MessageLookupByLibrary.simpleMessage("标准"),
    "card_style_standard_detail": MessageLookupByLibrary.simpleMessage(
      "封面、标题、信息与标签",
    ),
    "cf_verify_action": MessageLookupByLibrary.simpleMessage("去验证"),
    "cf_verify_prompt": MessageLookupByLibrary.simpleMessage(
      "论坛请求被 Cloudflare 拦截，要现在在内置浏览器中完成验证吗？",
    ),
    "cf_verify_required": MessageLookupByLibrary.simpleMessage("论坛需要验证"),
    "cf_verify_still_blocked": MessageLookupByLibrary.simpleMessage(
      "验证已保存，但论坛仍被拦截，请稍后或切换网络后再试",
    ),
    "cf_verify_success": MessageLookupByLibrary.simpleMessage("验证完成"),
    "cf_verify_summary": MessageLookupByLibrary.simpleMessage(
      "论坛请求被拦截时，在应用内重新完成人机验证",
    ),
    "cf_verify_title": MessageLookupByLibrary.simpleMessage("Cloudflare 验证"),
    "change_to_favorites": MessageLookupByLibrary.simpleMessage("修改收藏夹"),
    "chapter": MessageLookupByLibrary.simpleMessage("章节"),
    "check_download_files_and_continue": MessageLookupByLibrary.simpleMessage(
      "核对文件并继续",
    ),
    "check_for_update": MessageLookupByLibrary.simpleMessage("检查更新"),
    "choose_favcat": MessageLookupByLibrary.simpleMessage("选择收藏夹"),
    "clear_cache": MessageLookupByLibrary.simpleMessage("清除缓存"),
    "clear_filter": MessageLookupByLibrary.simpleMessage("重置"),
    "clear_search_history": MessageLookupByLibrary.simpleMessage("清空搜索历史"),
    "clipboard_detection": MessageLookupByLibrary.simpleMessage("剪贴板检测"),
    "clipboard_detection_desc": MessageLookupByLibrary.simpleMessage(
      "自动检测剪贴板画廊链接",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("折叠"),
    "color_picker_primary": MessageLookupByLibrary.simpleMessage("基本"),
    "color_picker_wheel": MessageLookupByLibrary.simpleMessage("色盘"),
    "column_count": m0,
    "column_range": m1,
    "comment": MessageLookupByLibrary.simpleMessage("评论"),
    "comment_count": m2,
    "commentator": MessageLookupByLibrary.simpleMessage("评论者"),
    "concurrent_galleries": MessageLookupByLibrary.simpleMessage("同时下载画廊任务数"),
    "continue_reading_page": m3,
    "copied_to_clipboard": MessageLookupByLibrary.simpleMessage("已复制到剪贴板"),
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copy_link": MessageLookupByLibrary.simpleMessage("复制链接"),
    "copy_title": MessageLookupByLibrary.simpleMessage("复制标题"),
    "current_site": m4,
    "current_version": MessageLookupByLibrary.simpleMessage("当前版本"),
    "custom_hosts": MessageLookupByLibrary.simpleMessage("自定义hosts"),
    "custom_width": MessageLookupByLibrary.simpleMessage("自定义宽度"),
    "dark": MessageLookupByLibrary.simpleMessage("深色模式"),
    "dark_mode_effect": MessageLookupByLibrary.simpleMessage("深色模式效果"),
    "date_or_offset": MessageLookupByLibrary.simpleMessage("日期或偏移量"),
    "default_avatar_style": MessageLookupByLibrary.simpleMessage("默认头像样式"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "delete_task": MessageLookupByLibrary.simpleMessage("删除任务"),
    "delete_task_and_content": MessageLookupByLibrary.simpleMessage(
      "删除任务和下载内容",
    ),
    "delete_task_only": MessageLookupByLibrary.simpleMessage("仅删除任务"),
    "desktop_all_history": MessageLookupByLibrary.simpleMessage("查看全部历史"),
    "desktop_clear_history_detail": MessageLookupByLibrary.simpleMessage(
      "清空本机浏览历史与最近阅读，保留阅读进度和下载文件。",
    ),
    "desktop_current_group": MessageLookupByLibrary.simpleMessage("当前分组"),
    "desktop_display_mode": MessageLookupByLibrary.simpleMessage("显示方式"),
    "desktop_follow_global": MessageLookupByLibrary.simpleMessage("跟随全局"),
    "desktop_global_mode": MessageLookupByLibrary.simpleMessage("全局显示方式"),
    "desktop_global_mode_hint": MessageLookupByLibrary.simpleMessage(
      "同时影响跟随全局的列表",
    ),
    "desktop_hide_sidebar": MessageLookupByLibrary.simpleMessage("隐藏侧栏"),
    "desktop_mode_sync_failed": MessageLookupByLibrary.simpleMessage(
      "显示方式已保存在本机，同步失败，请检查连接。",
    ),
    "desktop_no_groups": MessageLookupByLibrary.simpleMessage("暂无分组"),
    "desktop_read_unavailable": MessageLookupByLibrary.simpleMessage(
      "无法打开作品，请检查来源后重试。",
    ),
    "desktop_recent_empty": MessageLookupByLibrary.simpleMessage(
      "开始阅读后，最近阅读会显示在这里",
    ),
    "desktop_recent_reading": MessageLookupByLibrary.simpleMessage("最近阅读"),
    "desktop_refresh": MessageLookupByLibrary.simpleMessage("刷新当前列表"),
    "desktop_refreshing": MessageLookupByLibrary.simpleMessage("正在刷新当前列表"),
    "desktop_resize_panes": MessageLookupByLibrary.simpleMessage("调整画廊与详情宽度"),
    "desktop_show_sidebar": MessageLookupByLibrary.simpleMessage("显示侧栏"),
    "desktop_untitled": MessageLookupByLibrary.simpleMessage("未命名作品"),
    "desktop_view_details": MessageLookupByLibrary.simpleMessage("查看详情"),
    "detail_ambient_background": MessageLookupByLibrary.simpleMessage(
      "详情页氛围背景",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("直连"),
    "disabled": MessageLookupByLibrary.simpleMessage("停用"),
    "domain_fronting": MessageLookupByLibrary.simpleMessage("域名前置"),
    "donate": MessageLookupByLibrary.simpleMessage("捐赠"),
    "done": MessageLookupByLibrary.simpleMessage("完成"),
    "double_click_back": MessageLookupByLibrary.simpleMessage("再按一次返回退出"),
    "double_page_model": MessageLookupByLibrary.simpleMessage("双页模式"),
    "download": MessageLookupByLibrary.simpleMessage("下载"),
    "download_check_updates": MessageLookupByLibrary.simpleMessage("检测更新"),
    "download_checking_updates": MessageLookupByLibrary.simpleMessage("检测中…"),
    "download_files_unavailable": MessageLookupByLibrary.simpleMessage(
      "文件暂不可用",
    ),
    "download_has_update_badge": MessageLookupByLibrary.simpleMessage("有新版"),
    "download_incremental_reused_status": m5,
    "download_incremental_updating": MessageLookupByLibrary.simpleMessage(
      "增量中",
    ),
    "download_location": MessageLookupByLibrary.simpleMessage("下载路径"),
    "download_ori_image": MessageLookupByLibrary.simpleMessage("下载原图"),
    "download_ori_image_summary": MessageLookupByLibrary.simpleMessage(
      "危险! 会导致下载配额迅速流失, 出现 509 错误",
    ),
    "download_update_all": MessageLookupByLibrary.simpleMessage("全部更新"),
    "download_updates_checked_with_errors": m6,
    "download_updates_found": m7,
    "download_updates_none": MessageLookupByLibrary.simpleMessage(
      "所有已下载画廊均为最新版本",
    ),
    "downloaded": MessageLookupByLibrary.simpleMessage("已下载"),
    "downloading": MessageLookupByLibrary.simpleMessage("下载中"),
    "edit": MessageLookupByLibrary.simpleMessage("编辑"),
    "edit_block_rule": MessageLookupByLibrary.simpleMessage("编辑屏蔽规则"),
    "edit_comment": MessageLookupByLibrary.simpleMessage("编辑评论"),
    "eh": MessageLookupByLibrary.simpleMessage("E·H"),
    "ehentai_my_tags": MessageLookupByLibrary.simpleMessage("我的标签"),
    "ehentai_settings": MessageLookupByLibrary.simpleMessage("EHentai 设置"),
    "enable": MessageLookupByLibrary.simpleMessage("启用"),
    "english_title": MessageLookupByLibrary.simpleMessage("英文标题"),
    "enter_date_or_offset_or_gid": MessageLookupByLibrary.simpleMessage(
      "输入具体日期或偏移量 / GID",
    ),
    "expand": MessageLookupByLibrary.simpleMessage("展开"),
    "experimental_feature": MessageLookupByLibrary.simpleMessage("实验性功能"),
    "export": MessageLookupByLibrary.simpleMessage("导出"),
    "export_app_data": MessageLookupByLibrary.simpleMessage("导出应用数据"),
    "export_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "导出应用数据到本地文件",
    ),
    "favcat": MessageLookupByLibrary.simpleMessage("收藏夹"),
    "favorite_note_hint": MessageLookupByLibrary.simpleMessage("备注（可选）"),
    "favorites_order": MessageLookupByLibrary.simpleMessage("收藏夹排序"),
    "favorites_order_Use_favorited": MessageLookupByLibrary.simpleMessage(
      "按照收藏时间",
    ),
    "favorites_order_Use_posted": MessageLookupByLibrary.simpleMessage(
      "按照发布时间",
    ),
    "file_size": MessageLookupByLibrary.simpleMessage("大小"),
    "filter_by_uploader": MessageLookupByLibrary.simpleMessage("按上传者筛选"),
    "filter_comments_by_score": MessageLookupByLibrary.simpleMessage(
      "根据评分过滤评论",
    ),
    "filter_comments_by_score_summary": MessageLookupByLibrary.simpleMessage(
      "低于/等于此分数的评论将被隐藏",
    ),
    "fixed_height_of_list_items": MessageLookupByLibrary.simpleMessage(
      "固定列表项高度",
    ),
    "follow_system": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "full_title": MessageLookupByLibrary.simpleMessage("完整标题"),
    "full_title_in_gallery": MessageLookupByLibrary.simpleMessage("显示完整标题"),
    "full_title_in_gallery_subtitle": MessageLookupByLibrary.simpleMessage(
      "在列表和画廊页面分行显示另一语言标题",
    ),
    "fullscreen": MessageLookupByLibrary.simpleMessage("全屏"),
    "galery_site": MessageLookupByLibrary.simpleMessage("画廊站点"),
    "gallery_comments": MessageLookupByLibrary.simpleMessage("画廊评论"),
    "gallery_from_parent_hint": m8,
    "gallery_has_parent_hint": MessageLookupByLibrary.simpleMessage("含父画廊"),
    "gallery_info": MessageLookupByLibrary.simpleMessage("画廊信息"),
    "gallery_info_category": MessageLookupByLibrary.simpleMessage("分类"),
    "gallery_info_cover_url": MessageLookupByLibrary.simpleMessage("封面链接"),
    "gallery_info_expunged": MessageLookupByLibrary.simpleMessage("已删除"),
    "gallery_info_favorite_status": MessageLookupByLibrary.simpleMessage(
      "收藏状态",
    ),
    "gallery_info_gallery_url": MessageLookupByLibrary.simpleMessage("画廊链接"),
    "gallery_info_open_browser": MessageLookupByLibrary.simpleMessage("浏览器打开"),
    "gallery_info_open_browser_failed": MessageLookupByLibrary.simpleMessage(
      "无法在浏览器中打开链接",
    ),
    "gallery_info_posted": MessageLookupByLibrary.simpleMessage("发布时间"),
    "gallery_info_rating_votes": m9,
    "gallery_info_section_details": MessageLookupByLibrary.simpleMessage(
      "画廊属性",
    ),
    "gallery_info_section_identifiers": MessageLookupByLibrary.simpleMessage(
      "标识与链接",
    ),
    "gallery_info_section_titles": MessageLookupByLibrary.simpleMessage("标题"),
    "gallery_info_visible": MessageLookupByLibrary.simpleMessage("可见性"),
    "gallery_latest_version": MessageLookupByLibrary.simpleMessage("最新"),
    "gallery_lineage": MessageLookupByLibrary.simpleMessage("版本血缘"),
    "gallery_lineage_tap_hint": MessageLookupByLibrary.simpleMessage(
      "点按跳转 · 长按复制",
    ),
    "gallery_metadata": MessageLookupByLibrary.simpleMessage("基础元数据"),
    "gallery_metadata_copy_hint": MessageLookupByLibrary.simpleMessage("点按复制"),
    "gallery_newer_version_count": m10,
    "gallery_newer_version_single": MessageLookupByLibrary.simpleMessage(
      "有 1 个更新版本",
    ),
    "gallery_newer_versions": MessageLookupByLibrary.simpleMessage("更新版本"),
    "gallery_open_latest_version": MessageLookupByLibrary.simpleMessage(
      "前往最新版本",
    ),
    "gallery_open_parent": MessageLookupByLibrary.simpleMessage("前往父画廊"),
    "gallery_parent": MessageLookupByLibrary.simpleMessage("父画廊"),
    "gallery_parent_none": MessageLookupByLibrary.simpleMessage("无"),
    "gallery_parent_unavailable": MessageLookupByLibrary.simpleMessage("已不可用"),
    "gallery_stats": MessageLookupByLibrary.simpleMessage("画廊统计"),
    "gallery_stats_all_time": MessageLookupByLibrary.simpleMessage("历史总榜"),
    "gallery_stats_collapse": MessageLookupByLibrary.simpleMessage("收起"),
    "gallery_stats_current_version": m11,
    "gallery_stats_daily": MessageLookupByLibrary.simpleMessage("按日"),
    "gallery_stats_daily_avg": MessageLookupByLibrary.simpleMessage("历史日均"),
    "gallery_stats_empty_body": MessageLookupByLibrary.simpleMessage(
      "E-Hentai 的 stats.php 受账号权限（捐赠/上传者等）与画廊可见性限制，部分或非本人画廊可能无法查看。",
    ),
    "gallery_stats_empty_title": MessageLookupByLibrary.simpleMessage(
      "暂无可查看的统计数据",
    ),
    "gallery_stats_expand_action": MessageLookupByLibrary.simpleMessage(
      "查看画廊统计",
    ),
    "gallery_stats_expand_hint": MessageLookupByLibrary.simpleMessage(
      "按需加载 stats.php（受账号权限与站点可见性限制）",
    ),
    "gallery_stats_fav_rate": MessageLookupByLibrary.simpleMessage("收藏转化"),
    "gallery_stats_hits": MessageLookupByLibrary.simpleMessage("点击量"),
    "gallery_stats_load_failed": MessageLookupByLibrary.simpleMessage(
      "获取画廊统计失败",
    ),
    "gallery_stats_loading": MessageLookupByLibrary.simpleMessage("正在获取统计数据…"),
    "gallery_stats_login_required": MessageLookupByLibrary.simpleMessage(
      "需要登录 E-Hentai 账号后才能查看画廊统计",
    ),
    "gallery_stats_monthly": MessageLookupByLibrary.simpleMessage("按月"),
    "gallery_stats_no_rankings": MessageLookupByLibrary.simpleMessage(
      "暂未进入任何周期榜单",
    ),
    "gallery_stats_no_series_data": MessageLookupByLibrary.simpleMessage(
      "该周期暂无历史数据",
    ),
    "gallery_stats_open_web": MessageLookupByLibrary.simpleMessage(
      "打开 stats.php",
    ),
    "gallery_stats_past_month": MessageLookupByLibrary.simpleMessage("月度榜单"),
    "gallery_stats_past_year": MessageLookupByLibrary.simpleMessage("年度榜单"),
    "gallery_stats_peak": m12,
    "gallery_stats_period_avg": m13,
    "gallery_stats_period_share": m14,
    "gallery_stats_period_total": m15,
    "gallery_stats_ranking": MessageLookupByLibrary.simpleMessage("榜单排名"),
    "gallery_stats_refresh": MessageLookupByLibrary.simpleMessage("刷新统计"),
    "gallery_stats_retry": MessageLookupByLibrary.simpleMessage("重新获取"),
    "gallery_stats_score": m16,
    "gallery_stats_total_visits": MessageLookupByLibrary.simpleMessage("总浏览"),
    "gallery_stats_unranked": MessageLookupByLibrary.simpleMessage("未上榜"),
    "gallery_stats_visits": MessageLookupByLibrary.simpleMessage("浏览量"),
    "gallery_stats_yearly": MessageLookupByLibrary.simpleMessage("按年"),
    "gallery_stats_yesterday": MessageLookupByLibrary.simpleMessage("昨日榜单"),
    "gallery_updatable_hint": MessageLookupByLibrary.simpleMessage("可增量更新"),
    "gallery_updated_on": m17,
    "gallery_view_lineage_hint": MessageLookupByLibrary.simpleMessage("查看血缘"),
    "glass_effect": MessageLookupByLibrary.simpleMessage("玻璃效果"),
    "glass_material": MessageLookupByLibrary.simpleMessage("玻璃材质"),
    "glass_material_frosted": MessageLookupByLibrary.simpleMessage("毛玻璃"),
    "glass_material_frosted_detail": MessageLookupByLibrary.simpleMessage(
      "柔和模糊，性能更好",
    ),
    "glass_material_liquid": MessageLookupByLibrary.simpleMessage("液态玻璃"),
    "glass_material_liquid_detail": MessageLookupByLibrary.simpleMessage(
      "折射与高光，更耗电",
    ),
    "glass_system_bar_note": MessageLookupByLibrary.simpleMessage(
      "系统绘制的竖向标签栏（如 iPhone Duo 外屏的侧边栏）始终为液态玻璃。",
    ),
    "global_setting": MessageLookupByLibrary.simpleMessage("全局设置"),
    "gray_black": MessageLookupByLibrary.simpleMessage("石墨"),
    "group": MessageLookupByLibrary.simpleMessage("分组"),
    "groupName": MessageLookupByLibrary.simpleMessage("分组名称"),
    "groupType": MessageLookupByLibrary.simpleMessage("类型"),
    "group_management": MessageLookupByLibrary.simpleMessage("分组管理"),
    "hide": MessageLookupByLibrary.simpleMessage("隐藏"),
    "hide_gallery_thumbnails": MessageLookupByLibrary.simpleMessage("隐藏画廊缩略图"),
    "hide_thumbnails": MessageLookupByLibrary.simpleMessage("隐藏缩略图"),
    "hide_top_bar_on_scroll": MessageLookupByLibrary.simpleMessage("滚动时隐藏顶栏"),
    "high_resolution_images_limited": MessageLookupByLibrary.simpleMessage(
      "高分辨率图片限制",
    ),
    "horizontal_thumbnails": MessageLookupByLibrary.simpleMessage("水平缩略图"),
    "host": MessageLookupByLibrary.simpleMessage("地址"),
    "hours": MessageLookupByLibrary.simpleMessage("小时"),
    "image_block": MessageLookupByLibrary.simpleMessage("图片屏蔽"),
    "image_download_type": MessageLookupByLibrary.simpleMessage("下载类型"),
    "image_limits": MessageLookupByLibrary.simpleMessage("图片限制"),
    "image_save_busy": MessageLookupByLibrary.simpleMessage("图片正在保存，请稍候。"),
    "image_save_download": MessageLookupByLibrary.simpleMessage("图片下载失败，请重试。"),
    "image_save_invalid": MessageLookupByLibrary.simpleMessage(
      "图片文件不存在、不完整或无效。",
    ),
    "image_save_permission": MessageLookupByLibrary.simpleMessage(
      "未获准添加照片，请在系统设置中允许。使用 LiveContainer 时请检查宿主的照片权限。",
    ),
    "image_save_unsupported": MessageLookupByLibrary.simpleMessage(
      "系统相册不支持此图片格式。",
    ),
    "image_save_write": MessageLookupByLibrary.simpleMessage("写入相册失败，请重试。"),
    "import_app_data": MessageLookupByLibrary.simpleMessage("导入应用数据"),
    "import_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "从本地文件导入应用数据, 重启应用后生效",
    ),
    "import_export": MessageLookupByLibrary.simpleMessage("导入与导出"),
    "incremental_update_added": MessageLookupByLibrary.simpleMessage("新增页面"),
    "incremental_update_all_reused": MessageLookupByLibrary.simpleMessage(
      "全部页面可直接复用",
    ),
    "incremental_update_applying": MessageLookupByLibrary.simpleMessage(
      "正在应用更新…",
    ),
    "incremental_update_compare_failed": MessageLookupByLibrary.simpleMessage(
      "分析新版页面失败",
    ),
    "incremental_update_comparing": MessageLookupByLibrary.simpleMessage(
      "正在分析版本页面差异…",
    ),
    "incremental_update_completed_locally": m18,
    "incremental_update_entry": MessageLookupByLibrary.simpleMessage(
      "增量更新已下载画廊",
    ),
    "incremental_update_local_tag": MessageLookupByLibrary.simpleMessage("本地"),
    "incremental_update_mode_inplace": MessageLookupByLibrary.simpleMessage(
      "原位升级并保留阅读进度",
    ),
    "incremental_update_mode_inplace_desc": m19,
    "incremental_update_mode_new": MessageLookupByLibrary.simpleMessage(
      "作为新任务下载（保留旧版）",
    ),
    "incremental_update_mode_new_desc": m20,
    "incremental_update_mode_title": MessageLookupByLibrary.simpleMessage(
      "更新方式",
    ),
    "incremental_update_newer_tag": MessageLookupByLibrary.simpleMessage("新版"),
    "incremental_update_only_download": m21,
    "incremental_update_recommended": MessageLookupByLibrary.simpleMessage(
      "推荐",
    ),
    "incremental_update_replaced": MessageLookupByLibrary.simpleMessage("修订替换"),
    "incremental_update_reused": MessageLookupByLibrary.simpleMessage("直接复用"),
    "incremental_update_saf_inplace_unsupported":
        MessageLookupByLibrary.simpleMessage(
          "SAF 存储暂不支持本地文件复用或原位升级，将以新任务方式完整下载。",
        ),
    "incremental_update_start_inplace": m22,
    "incremental_update_start_new": m23,
    "incremental_update_start_reuse_only": MessageLookupByLibrary.simpleMessage(
      "直接完成本地升级（无需下载）",
    ),
    "incremental_update_start_saf_full": m24,
    "incremental_update_started": m25,
    "incremental_update_subtitle": MessageLookupByLibrary.simpleMessage(
      "复用本地未改动页面",
    ),
    "incremental_update_target_version": MessageLookupByLibrary.simpleMessage(
      "目标版本",
    ),
    "incremental_update_title": MessageLookupByLibrary.simpleMessage("画廊增量更新"),
    "incremental_update_version_compare": MessageLookupByLibrary.simpleMessage(
      "版本对比",
    ),
    "incremental_update_view_newer": MessageLookupByLibrary.simpleMessage(
      "先查看新版详情页",
    ),
    "inner_display": MessageLookupByLibrary.simpleMessage("内屏"),
    "input_empty": MessageLookupByLibrary.simpleMessage("输入空"),
    "input_error": MessageLookupByLibrary.simpleMessage("输入格式有误"),
    "instantly": MessageLookupByLibrary.simpleMessage("立即"),
    "japanese_title": MessageLookupByLibrary.simpleMessage("日文标题"),
    "japanese_title_in_gallery": MessageLookupByLibrary.simpleMessage(
      "画廊页面显示日文标题",
    ),
    "japanese_title_in_gallery_summary": MessageLookupByLibrary.simpleMessage(
      "日文标题仅在画廊页面生效",
    ),
    "jump_next": MessageLookupByLibrary.simpleMessage("后面"),
    "jump_or_seek": MessageLookupByLibrary.simpleMessage("跳转/搜寻"),
    "jump_prev": MessageLookupByLibrary.simpleMessage("前面"),
    "jump_to_page": MessageLookupByLibrary.simpleMessage("页面跳转"),
    "landscape": MessageLookupByLibrary.simpleMessage("横屏"),
    "language": MessageLookupByLibrary.simpleMessage("语言设置"),
    "last_favorites": MessageLookupByLibrary.simpleMessage("使用上次选择，长按选择其他"),
    "latest_version": MessageLookupByLibrary.simpleMessage("最新版本"),
    "layout": MessageLookupByLibrary.simpleMessage("样式"),
    "left_to_right": MessageLookupByLibrary.simpleMessage("从左到右"),
    "license": MessageLookupByLibrary.simpleMessage("开源许可"),
    "light": MessageLookupByLibrary.simpleMessage("浅色模式"),
    "link_redirect": MessageLookupByLibrary.simpleMessage("链接重定向"),
    "link_redirect_summary": MessageLookupByLibrary.simpleMessage(
      "将画廊链接重定向到选定的站点",
    ),
    "liquid_glass_description": MessageLookupByLibrary.simpleMessage(
      "为导航栏、标签栏、按钮和弹出菜单使用玻璃效果。毛玻璃更省电、滑动更流畅。",
    ),
    "liquid_glass_inline": MessageLookupByLibrary.simpleMessage("单行紧凑"),
    "liquid_glass_inline_detail": MessageLookupByLibrary.simpleMessage(
      "操作与分组共用一行，节省页面高度",
    ),
    "liquid_glass_top_layout": MessageLookupByLibrary.simpleMessage("顶栏分组布局"),
    "liquid_glass_two_row": MessageLookupByLibrary.simpleMessage("两行展开（默认）"),
    "liquid_glass_two_row_detail": MessageLookupByLibrary.simpleMessage(
      "操作与分组分行显示，适合较多分组和长名称",
    ),
    "list_load_more_fail": MessageLookupByLibrary.simpleMessage("加载失败, 点击重试"),
    "list_mode": MessageLookupByLibrary.simpleMessage("列表样式"),
    "listmode_grid": MessageLookupByLibrary.simpleMessage("网格"),
    "listmode_grid_tags": MessageLookupByLibrary.simpleMessage("网格 - 标签"),
    "listmode_medium": MessageLookupByLibrary.simpleMessage("列表 - 中"),
    "listmode_small": MessageLookupByLibrary.simpleMessage("列表 - 小"),
    "listmode_waterfall": MessageLookupByLibrary.simpleMessage("瀑布流"),
    "listmode_waterfall_large": MessageLookupByLibrary.simpleMessage("瀑布流 - 大"),
    "loading": MessageLookupByLibrary.simpleMessage("载入中"),
    "local_favorite": MessageLookupByLibrary.simpleMessage("本地收藏"),
    "login": MessageLookupByLibrary.simpleMessage("登录"),
    "login_web": MessageLookupByLibrary.simpleMessage("通过网页登录"),
    "max_history": MessageLookupByLibrary.simpleMessage("最大历史记录"),
    "min": MessageLookupByLibrary.simpleMessage("分钟"),
    "model": m26,
    "more_actions": MessageLookupByLibrary.simpleMessage("更多"),
    "more_thumbnails": MessageLookupByLibrary.simpleMessage("更多缩略图"),
    "multi_download": MessageLookupByLibrary.simpleMessage("同时下载图片数量"),
    "mytags_on_website": MessageLookupByLibrary.simpleMessage("网页上的标签设置"),
    "native_http_client_adapter": MessageLookupByLibrary.simpleMessage(
      "使用原生 HTTP 客户端",
    ),
    "never": MessageLookupByLibrary.simpleMessage("禁用"),
    "newGroup": MessageLookupByLibrary.simpleMessage("新建分组"),
    "newText": MessageLookupByLibrary.simpleMessage("新关键词"),
    "new_comment": MessageLookupByLibrary.simpleMessage("发布新评论"),
    "no": MessageLookupByLibrary.simpleMessage("不"),
    "no_limit": MessageLookupByLibrary.simpleMessage("无限制"),
    "no_more_thumbnails": MessageLookupByLibrary.simpleMessage("无更多缩略图"),
    "notFav": MessageLookupByLibrary.simpleMessage("未收藏"),
    "not_login": MessageLookupByLibrary.simpleMessage("未登录"),
    "off": MessageLookupByLibrary.simpleMessage("关闭"),
    "ok": MessageLookupByLibrary.simpleMessage("确定"),
    "on": MessageLookupByLibrary.simpleMessage("打开"),
    "one_step_favorite": MessageLookupByLibrary.simpleMessage("单点收藏"),
    "one_step_favorite_desc": MessageLookupByLibrary.simpleMessage(
      "快速将画廊添加到收藏夹，短按保存到上次选择的收藏夹，长按显示收藏夹对话框",
    ),
    "open_supported_links": MessageLookupByLibrary.simpleMessage("打开支持的链接"),
    "open_supported_links_summary": MessageLookupByLibrary.simpleMessage(
      "从 Android 12 开始, 应用只有在获得批准的情况下，才能作为网络链接的处理应用。否则会使用默认浏览器处理。您可以在此手动批准",
    ),
    "open_with_other_apps": MessageLookupByLibrary.simpleMessage("其他应用打开"),
    "orientation_auto": MessageLookupByLibrary.simpleMessage("自动旋转"),
    "orientation_landscapeLeft": MessageLookupByLibrary.simpleMessage("横屏(左)"),
    "orientation_landscapeRight": MessageLookupByLibrary.simpleMessage("横屏(右)"),
    "orientation_portraitUp": MessageLookupByLibrary.simpleMessage("竖屏"),
    "orientation_system": MessageLookupByLibrary.simpleMessage("系统默认"),
    "original_image": MessageLookupByLibrary.simpleMessage("原图"),
    "outer_display": MessageLookupByLibrary.simpleMessage("外屏"),
    "p_Archiver": MessageLookupByLibrary.simpleMessage("归档"),
    "p_Download": MessageLookupByLibrary.simpleMessage("下载"),
    "p_Rate": MessageLookupByLibrary.simpleMessage("评分"),
    "p_Similar": MessageLookupByLibrary.simpleMessage("相似"),
    "p_Torrent": MessageLookupByLibrary.simpleMessage("种子"),
    "page_count": m27,
    "page_range": MessageLookupByLibrary.simpleMessage("跳转范围"),
    "page_range_error": MessageLookupByLibrary.simpleMessage("输入范围有误"),
    "page_view_type": MessageLookupByLibrary.simpleMessage("页面视图类型"),
    "passwd": MessageLookupByLibrary.simpleMessage("密码"),
    "paused": MessageLookupByLibrary.simpleMessage("已暂停"),
    "phash_block_list": MessageLookupByLibrary.simpleMessage("感知哈希屏蔽列表"),
    "phash_check": MessageLookupByLibrary.simpleMessage("感知哈希检查 (屏蔽相似图片)"),
    "pls_i_passwd": MessageLookupByLibrary.simpleMessage("请输入密码"),
    "pls_i_username": MessageLookupByLibrary.simpleMessage("请输入用户名"),
    "port": MessageLookupByLibrary.simpleMessage("端口"),
    "portrait": MessageLookupByLibrary.simpleMessage("竖屏"),
    "preload_image": MessageLookupByLibrary.simpleMessage("预载图片数量"),
    "processing": MessageLookupByLibrary.simpleMessage("处理中"),
    "proxy": MessageLookupByLibrary.simpleMessage("代理"),
    "proxy_type": MessageLookupByLibrary.simpleMessage("代理类型"),
    "pure_black": MessageLookupByLibrary.simpleMessage("纯黑"),
    "quick_search": MessageLookupByLibrary.simpleMessage("快速搜索"),
    "ranking_period": MessageLookupByLibrary.simpleMessage("排行周期"),
    "read": MessageLookupByLibrary.simpleMessage("阅读"),
    "read_from_clipboard": MessageLookupByLibrary.simpleMessage("从剪贴板读取"),
    "read_setting": MessageLookupByLibrary.simpleMessage("阅读设置"),
    "read_view_compatible_mode": MessageLookupByLibrary.simpleMessage("兼容模式"),
    "reader_auto_read": MessageLookupByLibrary.simpleMessage("自动翻页"),
    "reader_auto_read_interval": MessageLookupByLibrary.simpleMessage("翻页间隔"),
    "reader_custom_interval": MessageLookupByLibrary.simpleMessage("自定义…"),
    "reader_double_even_left": MessageLookupByLibrary.simpleMessage(
      "双页（偶数页在左）",
    ),
    "reader_double_odd_left": MessageLookupByLibrary.simpleMessage("双页（奇数页在左）"),
    "reader_double_page": MessageLookupByLibrary.simpleMessage("双页"),
    "reader_fill_footer": MessageLookupByLibrary.simpleMessage(
      "开启后该方向阅读时隐藏状态栏等系统符号，图片忽略安全区铺满整屏",
    ),
    "reader_fill_landscape": MessageLookupByLibrary.simpleMessage("横屏铺满全屏"),
    "reader_fill_portrait": MessageLookupByLibrary.simpleMessage("竖屏铺满全屏"),
    "reader_interval_seconds": m28,
    "reader_next_page": MessageLookupByLibrary.simpleMessage("下一页"),
    "reader_page_layout": MessageLookupByLibrary.simpleMessage("页面版式"),
    "reader_page_of": m29,
    "reader_previous_page": MessageLookupByLibrary.simpleMessage("上一页"),
    "reader_single_page": MessageLookupByLibrary.simpleMessage("单页"),
    "reader_surface_standard": MessageLookupByLibrary.simpleMessage("标准"),
    "reader_surface_tabletop": MessageLookupByLibrary.simpleMessage("桌面模式"),
    "reader_turn_page": MessageLookupByLibrary.simpleMessage("翻页"),
    "reader_vertical": MessageLookupByLibrary.simpleMessage("纵向"),
    "reading_direction": MessageLookupByLibrary.simpleMessage("阅读方向"),
    "rebuild_tasks_data": MessageLookupByLibrary.simpleMessage("重建下载任务数据"),
    "redirect_thumb_link": MessageLookupByLibrary.simpleMessage("重定向缩略图链接"),
    "redirect_thumb_link_summary": MessageLookupByLibrary.simpleMessage(
      "重定向缩略图链接为ehgt.org",
    ),
    "redownload": MessageLookupByLibrary.simpleMessage("重新下载"),
    "refresh_igneous": MessageLookupByLibrary.simpleMessage("刷新Igneous"),
    "regex": MessageLookupByLibrary.simpleMessage("正则表达式"),
    "regex_format_error": MessageLookupByLibrary.simpleMessage("正则表达式格式错误"),
    "reload": MessageLookupByLibrary.simpleMessage("重新载入"),
    "reload_image": MessageLookupByLibrary.simpleMessage("重新载入图片"),
    "remove_all": MessageLookupByLibrary.simpleMessage("全部删除"),
    "remove_from_favorites": MessageLookupByLibrary.simpleMessage("从收藏夹中删除"),
    "reply_to_comment": MessageLookupByLibrary.simpleMessage("回复"),
    "resample_image": MessageLookupByLibrary.simpleMessage("重采样图片"),
    "reset_cost": MessageLookupByLibrary.simpleMessage("重置花费"),
    "restore_tasks_data": MessageLookupByLibrary.simpleMessage("恢复下载任务数据"),
    "right_to_left": MessageLookupByLibrary.simpleMessage("从右到左"),
    "s_Advanced_Options": MessageLookupByLibrary.simpleMessage("高级选项"),
    "s_Between": MessageLookupByLibrary.simpleMessage("从"),
    "s_Disable_default_filters": MessageLookupByLibrary.simpleMessage(
      "禁用默认排除选项",
    ),
    "s_Minimum_Rating": MessageLookupByLibrary.simpleMessage("最低评分"),
    "s_Only_Show_Galleries_With_Torrents": MessageLookupByLibrary.simpleMessage(
      "仅显示有种子的画廊",
    ),
    "s_Search_Downvoted_Tags": MessageLookupByLibrary.simpleMessage("搜索差评标签"),
    "s_Search_Fav_Name": MessageLookupByLibrary.simpleMessage("搜索名称"),
    "s_Search_Fav_Note": MessageLookupByLibrary.simpleMessage("搜索标注"),
    "s_Search_Fav_Tags": MessageLookupByLibrary.simpleMessage("搜索标签"),
    "s_Search_Gallery_Description": MessageLookupByLibrary.simpleMessage(
      "搜索画廊描述",
    ),
    "s_Search_Gallery_Name": MessageLookupByLibrary.simpleMessage("搜索画廊名字"),
    "s_Search_Gallery_Tags": MessageLookupByLibrary.simpleMessage("搜索画廊标签"),
    "s_Search_Low_Power_Tags": MessageLookupByLibrary.simpleMessage("搜索低愿力标签"),
    "s_Search_Torrent_Filenames": MessageLookupByLibrary.simpleMessage(
      "搜索种子名字",
    ),
    "s_Show_Expunged_Galleries": MessageLookupByLibrary.simpleMessage(
      "搜索被删除的画廊",
    ),
    "s_and": MessageLookupByLibrary.simpleMessage("到"),
    "s_pages": MessageLookupByLibrary.simpleMessage("页数"),
    "s_stars": m30,
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "save_current_image": MessageLookupByLibrary.simpleMessage("保存当前图片"),
    "save_into_album": MessageLookupByLibrary.simpleMessage("保存到相册"),
    "save_original_image": MessageLookupByLibrary.simpleMessage("保存原图"),
    "saved_successfully": MessageLookupByLibrary.simpleMessage("保存成功"),
    "screen_orientation": MessageLookupByLibrary.simpleMessage("屏幕方向"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "searchTexts": MessageLookupByLibrary.simpleMessage("搜索关键词"),
    "search_by_image": MessageLookupByLibrary.simpleMessage("以图搜图"),
    "search_history": MessageLookupByLibrary.simpleMessage("搜索历史"),
    "search_title": MessageLookupByLibrary.simpleMessage("搜索标题"),
    "search_type": MessageLookupByLibrary.simpleMessage("搜索类型"),
    "second": MessageLookupByLibrary.simpleMessage("秒"),
    "security": MessageLookupByLibrary.simpleMessage("安全"),
    "security_blurredInRecentTasks": MessageLookupByLibrary.simpleMessage(
      "最近任务中模糊处理",
    ),
    "see_all": MessageLookupByLibrary.simpleMessage("全部"),
    "setting_group_browse": MessageLookupByLibrary.simpleMessage("浏览"),
    "setting_group_content": MessageLookupByLibrary.simpleMessage("内容"),
    "setting_group_system": MessageLookupByLibrary.simpleMessage("系统"),
    "setting_on_website": MessageLookupByLibrary.simpleMessage("网页上的设置"),
    "setting_site": MessageLookupByLibrary.simpleMessage("站点"),
    "share": MessageLookupByLibrary.simpleMessage("分享"),
    "share_image": MessageLookupByLibrary.simpleMessage("分享图片"),
    "show_comment_avatar": MessageLookupByLibrary.simpleMessage("显示评论头像"),
    "show_comments": MessageLookupByLibrary.simpleMessage("显示画廊评论"),
    "show_english_title": MessageLookupByLibrary.simpleMessage("显示英文标题"),
    "show_filter": MessageLookupByLibrary.simpleMessage("显示筛选"),
    "show_gallery_tags": MessageLookupByLibrary.simpleMessage("显示画廊标签"),
    "show_japanese_title": MessageLookupByLibrary.simpleMessage("显示日文标题"),
    "show_jpn_title": MessageLookupByLibrary.simpleMessage("显示日文标题"),
    "show_only_uploader_comment": MessageLookupByLibrary.simpleMessage(
      "仅显示上传者评论",
    ),
    "show_page_interval": MessageLookupByLibrary.simpleMessage("显示页面间隔"),
    "sidebar_library": MessageLookupByLibrary.simpleMessage("资料库"),
    "skip": MessageLookupByLibrary.simpleMessage("跳过"),
    "slide_out_page": MessageLookupByLibrary.simpleMessage("拖动返回"),
    "sp_add_quick_search": MessageLookupByLibrary.simpleMessage("加入快速搜索"),
    "sp_add_tag": m31,
    "sp_all": MessageLookupByLibrary.simpleMessage("全部"),
    "sp_all_favcats": MessageLookupByLibrary.simpleMessage("全部收藏"),
    "sp_archive_original": MessageLookupByLibrary.simpleMessage("原图归档"),
    "sp_archive_resample": MessageLookupByLibrary.simpleMessage("重采样归档"),
    "sp_archiver_error": MessageLookupByLibrary.simpleMessage("读取失败"),
    "sp_archiver_hath": MessageLookupByLibrary.simpleMessage("H@H 远程下载"),
    "sp_archiver_loading": MessageLookupByLibrary.simpleMessage("正在读取归档信息"),
    "sp_archiver_local": MessageLookupByLibrary.simpleMessage("下载到本机"),
    "sp_category": MessageLookupByLibrary.simpleMessage("分类"),
    "sp_change_image": MessageLookupByLibrary.simpleMessage("更换"),
    "sp_clear": MessageLookupByLibrary.simpleMessage("清除"),
    "sp_clear_text": MessageLookupByLibrary.simpleMessage("清空搜索词"),
    "sp_date": MessageLookupByLibrary.simpleMessage("日期"),
    "sp_done": MessageLookupByLibrary.simpleMessage("完成"),
    "sp_favcat": MessageLookupByLibrary.simpleMessage("收藏夹"),
    "sp_filter": MessageLookupByLibrary.simpleMessage("筛选"),
    "sp_first_page": MessageLookupByLibrary.simpleMessage("第一页"),
    "sp_free": MessageLookupByLibrary.simpleMessage("免费"),
    "sp_go": MessageLookupByLibrary.simpleMessage("跳转"),
    "sp_hide_keyboard": MessageLookupByLibrary.simpleMessage("收起键盘"),
    "sp_image_search": MessageLookupByLibrary.simpleMessage("以图搜图"),
    "sp_image_search_options": MessageLookupByLibrary.simpleMessage("搜索选项"),
    "sp_include_expunged": MessageLookupByLibrary.simpleMessage("包含已删除"),
    "sp_invert_selection": MessageLookupByLibrary.simpleMessage("反选"),
    "sp_last_page": MessageLookupByLibrary.simpleMessage("最后一页"),
    "sp_middle_page": MessageLookupByLibrary.simpleMessage("中间"),
    "sp_more": MessageLookupByLibrary.simpleMessage("更多"),
    "sp_only_covers": MessageLookupByLibrary.simpleMessage("仅搜索封面"),
    "sp_open_link": MessageLookupByLibrary.simpleMessage("打开画廊链接"),
    "sp_optional": MessageLookupByLibrary.simpleMessage("可选"),
    "sp_original": MessageLookupByLibrary.simpleMessage("原图"),
    "sp_page_first": MessageLookupByLibrary.simpleMessage("首页"),
    "sp_page_last": MessageLookupByLibrary.simpleMessage("末页"),
    "sp_page_next": MessageLookupByLibrary.simpleMessage("下一页"),
    "sp_page_prev": MessageLookupByLibrary.simpleMessage("上一页"),
    "sp_page_total": m32,
    "sp_pick_image": MessageLookupByLibrary.simpleMessage("点击选择图片"),
    "sp_quick_search_list": MessageLookupByLibrary.simpleMessage("快速搜索列表"),
    "sp_rate_submit": MessageLookupByLibrary.simpleMessage("提交评分"),
    "sp_rating_summary": m33,
    "sp_recent_searches": MessageLookupByLibrary.simpleMessage("最近搜索"),
    "sp_refresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "sp_reset": MessageLookupByLibrary.simpleMessage("重置"),
    "sp_retry": MessageLookupByLibrary.simpleMessage("重试"),
    "sp_search_for": m34,
    "sp_search_placeholder": MessageLookupByLibrary.simpleMessage(
      "搜索标题、标签或粘贴链接",
    ),
    "sp_seek_hint": MessageLookupByLibrary.simpleMessage(
      "日期 2024-05-01 · 偏移 3d 2w 1y · 或直接填 GID",
    ),
    "sp_seek_newer": MessageLookupByLibrary.simpleMessage("看更新的"),
    "sp_seek_older": MessageLookupByLibrary.simpleMessage("看更早的"),
    "sp_seek_section": MessageLookupByLibrary.simpleMessage("按日期或 GID 定位"),
    "sp_select_all": MessageLookupByLibrary.simpleMessage("全选"),
    "sp_show_date_picker": MessageLookupByLibrary.simpleMessage("选择日期"),
    "sp_similar_scan": MessageLookupByLibrary.simpleMessage("相似扫描"),
    "sp_start_search": MessageLookupByLibrary.simpleMessage("开始搜索"),
    "sp_suggestions": MessageLookupByLibrary.simpleMessage("建议"),
    "sp_tags_added": m35,
    "sp_tags_example": MessageLookupByLibrary.simpleMessage(
      "例如 female:glasses, full color",
    ),
    "sp_thumbs_jump": MessageLookupByLibrary.simpleMessage("跳到预览页"),
    "sp_thumbs_per_page": m36,
    "sp_torrent_completed": MessageLookupByLibrary.simpleMessage("完成"),
    "sp_torrent_download": MessageLookupByLibrary.simpleMessage("下载种子"),
    "sp_torrent_empty": MessageLookupByLibrary.simpleMessage("没有可用的种子"),
    "sp_torrent_magnet": MessageLookupByLibrary.simpleMessage("分享磁力"),
    "sp_torrent_peers": MessageLookupByLibrary.simpleMessage("下载中"),
    "sp_torrent_seeds": MessageLookupByLibrary.simpleMessage("做种"),
    "sp_torrent_title": m37,
    "sp_translate": MessageLookupByLibrary.simpleMessage("翻译"),
    "split_follows_divider": MessageLookupByLibrary.simpleMessage("分栏随分割条"),
    "sync_group": MessageLookupByLibrary.simpleMessage("同步分组"),
    "sync_history": MessageLookupByLibrary.simpleMessage("同步历史记录"),
    "sync_quick_search": MessageLookupByLibrary.simpleMessage("同步快速搜索"),
    "sync_read_progress": MessageLookupByLibrary.simpleMessage("同步阅读进度"),
    "system_proxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "system_share": MessageLookupByLibrary.simpleMessage("系统分享"),
    "t_Clear_all_history": MessageLookupByLibrary.simpleMessage("清除所有历史"),
    "tab_download": MessageLookupByLibrary.simpleMessage("下载"),
    "tab_favorite": MessageLookupByLibrary.simpleMessage("收藏"),
    "tab_gallery": MessageLookupByLibrary.simpleMessage("画廊"),
    "tab_history": MessageLookupByLibrary.simpleMessage("历史"),
    "tab_history_duo_sidebar_note": MessageLookupByLibrary.simpleMessage(
      "「历史」栏位不会显示在 iPhone Duo 侧边栏中，可从页面顶部操作栏进入。",
    ),
    "tab_popular": MessageLookupByLibrary.simpleMessage("热门"),
    "tab_setting": MessageLookupByLibrary.simpleMessage("设置"),
    "tab_sort": MessageLookupByLibrary.simpleMessage("长按并拖动以进行排序"),
    "tab_toplist": MessageLookupByLibrary.simpleMessage("排行"),
    "tab_watched": MessageLookupByLibrary.simpleMessage("订阅"),
    "tabbar_setting": MessageLookupByLibrary.simpleMessage("主页栏位设置"),
    "tablet_layout": MessageLookupByLibrary.simpleMessage("平板布局"),
    "tagNamespace": m38,
    "tag_add_to_mytag": MessageLookupByLibrary.simpleMessage("管理标签"),
    "tag_dialog_Default_color": MessageLookupByLibrary.simpleMessage("默认颜色"),
    "tag_dialog_Hide": MessageLookupByLibrary.simpleMessage("隐藏"),
    "tag_dialog_TagColor": MessageLookupByLibrary.simpleMessage("标签颜色"),
    "tag_dialog_Watch": MessageLookupByLibrary.simpleMessage("订阅"),
    "tag_dialog_tagWeight": MessageLookupByLibrary.simpleMessage("标签权重"),
    "tag_limit": MessageLookupByLibrary.simpleMessage("标签上限"),
    "tag_vote_down": MessageLookupByLibrary.simpleMessage("反对标签"),
    "tag_vote_up": MessageLookupByLibrary.simpleMessage("赞成标签"),
    "tag_withdraw_vote": MessageLookupByLibrary.simpleMessage("撤销投票"),
    "tags": MessageLookupByLibrary.simpleMessage("标签"),
    "tap_to_turn_page_anima": MessageLookupByLibrary.simpleMessage("点击翻页动画"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "thumbnails": MessageLookupByLibrary.simpleMessage("缩略图"),
    "title": MessageLookupByLibrary.simpleMessage("标题"),
    "title_showing": MessageLookupByLibrary.simpleMessage("当前显示"),
    "tolist_alltime": MessageLookupByLibrary.simpleMessage("总排行"),
    "tolist_past_month": MessageLookupByLibrary.simpleMessage("月排行"),
    "tolist_past_year": MessageLookupByLibrary.simpleMessage("年排行"),
    "tolist_yesterday": MessageLookupByLibrary.simpleMessage("日排行"),
    "top_to_bottom": MessageLookupByLibrary.simpleMessage("从上到下"),
    "turn_page_anima": MessageLookupByLibrary.simpleMessage("翻页动画"),
    "uc_Chinese": MessageLookupByLibrary.simpleMessage("汉语"),
    "uc_Dutch": MessageLookupByLibrary.simpleMessage("荷兰语"),
    "uc_English": MessageLookupByLibrary.simpleMessage("英语"),
    "uc_French": MessageLookupByLibrary.simpleMessage("法语"),
    "uc_German": MessageLookupByLibrary.simpleMessage("德语"),
    "uc_Hungarian": MessageLookupByLibrary.simpleMessage("匈牙利语"),
    "uc_Italian": MessageLookupByLibrary.simpleMessage("意大利语"),
    "uc_Japanese": MessageLookupByLibrary.simpleMessage("日语"),
    "uc_Korean": MessageLookupByLibrary.simpleMessage("韩语"),
    "uc_NA": MessageLookupByLibrary.simpleMessage("无语言"),
    "uc_Original": MessageLookupByLibrary.simpleMessage("原始"),
    "uc_Other": MessageLookupByLibrary.simpleMessage("其他"),
    "uc_Polish": MessageLookupByLibrary.simpleMessage("波兰语"),
    "uc_Portuguese": MessageLookupByLibrary.simpleMessage("葡萄牙语"),
    "uc_Rewrite": MessageLookupByLibrary.simpleMessage("重写"),
    "uc_Russian": MessageLookupByLibrary.simpleMessage("俄语"),
    "uc_Spanish": MessageLookupByLibrary.simpleMessage("西班牙语"),
    "uc_Thai": MessageLookupByLibrary.simpleMessage("泰语"),
    "uc_Translated": MessageLookupByLibrary.simpleMessage("翻译"),
    "uc_Vietnamese": MessageLookupByLibrary.simpleMessage("越南语"),
    "uc_ar_0": MessageLookupByLibrary.simpleMessage("手动选择，手动下载（默认）"),
    "uc_ar_1": MessageLookupByLibrary.simpleMessage("手动选择，自动下载"),
    "uc_ar_2": MessageLookupByLibrary.simpleMessage("自动选择原始画质，手动下载"),
    "uc_ar_3": MessageLookupByLibrary.simpleMessage("自动选择原始画质，自动下载"),
    "uc_ar_4": MessageLookupByLibrary.simpleMessage("自动选择压缩画质，手动下载"),
    "uc_ar_5": MessageLookupByLibrary.simpleMessage("自动选择压缩画质，自动下载"),
    "uc_archiver_desc": MessageLookupByLibrary.simpleMessage(
      "默认归档下载方式为手动选择（原画质或压缩画质），然后手动复制或点击下载链接。你可以修改归档下载方式。",
    ),
    "uc_archiver_set": MessageLookupByLibrary.simpleMessage("归档设置"),
    "uc_artist": MessageLookupByLibrary.simpleMessage("艺术家"),
    "uc_auto": MessageLookupByLibrary.simpleMessage("自动"),
    "uc_character": MessageLookupByLibrary.simpleMessage("角色"),
    "uc_comments_show_votes": MessageLookupByLibrary.simpleMessage("显示投票数"),
    "uc_comments_sort_order": MessageLookupByLibrary.simpleMessage("排序方式"),
    "uc_crt_profile": MessageLookupByLibrary.simpleMessage("新建"),
    "uc_cs_0": MessageLookupByLibrary.simpleMessage("最早的评论"),
    "uc_cs_1": MessageLookupByLibrary.simpleMessage("最新的评论"),
    "uc_cs_2": MessageLookupByLibrary.simpleMessage("最高分的评论"),
    "uc_del_profile": MessageLookupByLibrary.simpleMessage("删除配置"),
    "uc_dm_0": MessageLookupByLibrary.simpleMessage("紧凑 + 标签"),
    "uc_dm_1": MessageLookupByLibrary.simpleMessage("缩略图"),
    "uc_dm_2": MessageLookupByLibrary.simpleMessage("扩展"),
    "uc_dm_3": MessageLookupByLibrary.simpleMessage("最小化"),
    "uc_dm_4": MessageLookupByLibrary.simpleMessage("最小化 + 关注标签"),
    "uc_exc_lang": MessageLookupByLibrary.simpleMessage("排除语言"),
    "uc_exc_lang_desc": MessageLookupByLibrary.simpleMessage(
      "如果您希望以图库列表中的某些语言隐藏图库并进行搜索，请从下面的列表中选择它们。\n请注意，无论搜索查询如何，匹配的图库都不会出现。",
    ),
    "uc_exc_up": MessageLookupByLibrary.simpleMessage("屏蔽的上传者"),
    "uc_exc_up_desc": MessageLookupByLibrary.simpleMessage(
      "如果你希望在图库中和搜索中隐藏某个上传者的话，请把他们的用户名填写在上方，每行一个。\n注意：无论你如何搜索，这些上传者都不会出现。",
    ),
    "uc_fav": MessageLookupByLibrary.simpleMessage("收藏"),
    "uc_fav_sort": MessageLookupByLibrary.simpleMessage("默认排序"),
    "uc_fav_sort_desc": MessageLookupByLibrary.simpleMessage(
      "请注意，2016 年 3 月改版之前加入收藏夹的图库并未保存收藏时间，会以图库发布时间代替。",
    ),
    "uc_female": MessageLookupByLibrary.simpleMessage("女性"),
    "uc_front_page": MessageLookupByLibrary.simpleMessage("首页设置"),
    "uc_front_page_dis_mode": MessageLookupByLibrary.simpleMessage("首页显示样式"),
    "uc_fs_0": MessageLookupByLibrary.simpleMessage("按最新更新时间排序"),
    "uc_fs_1": MessageLookupByLibrary.simpleMessage("按收藏时间排序"),
    "uc_gallery_comments": MessageLookupByLibrary.simpleMessage("图库评论"),
    "uc_group": MessageLookupByLibrary.simpleMessage("社团"),
    "uc_hath_local_host": MessageLookupByLibrary.simpleMessage(
      "Hentai@Home 本地网络服务器",
    ),
    "uc_hath_local_host_desc": MessageLookupByLibrary.simpleMessage(
      "    如果你本地安装了 H@H 客户端，本地 IP 与浏览网站的公共 IP 相同，一些路由器不支持回流导致无法访问到自己，你可以设置这里来解决。\n    如果在同一台电脑上访问网站和运行客户端，请使用本地回环地址（127.0.0.1:端口号）。如果客户端在网络上的其他计算机运行，请使用那台机器的内网 IP。某些浏览器的配置可能阻止外部网站访问本地网络，你必须将网站列入白名单才能工作。",
    ),
    "uc_img_cussize_desc": MessageLookupByLibrary.simpleMessage(
      "虽然图片会自动根据窗口缩小，你也可以手动设置最大大小，图片并没有重新采样（0 为不限制）",
    ),
    "uc_img_horiz": MessageLookupByLibrary.simpleMessage("宽/横向"),
    "uc_img_load_setting": MessageLookupByLibrary.simpleMessage("图片加载设置"),
    "uc_img_size_setting": MessageLookupByLibrary.simpleMessage("图片大小设置"),
    "uc_img_vert": MessageLookupByLibrary.simpleMessage("高/纵向"),
    "uc_ip_addr_port": MessageLookupByLibrary.simpleMessage("IP Address:Port"),
    "uc_language": MessageLookupByLibrary.simpleMessage("语言"),
    "uc_lt_0": MessageLookupByLibrary.simpleMessage("鼠标悬停时 (页面加载快，缩略图加载有延迟)"),
    "uc_lt_0_s": MessageLookupByLibrary.simpleMessage("鼠标悬停时"),
    "uc_lt_1": MessageLookupByLibrary.simpleMessage(
      "页面加载时 (页面加载时间更长，但是显示的时候无需等待)",
    ),
    "uc_lt_1_s": MessageLookupByLibrary.simpleMessage("页面加载时"),
    "uc_male": MessageLookupByLibrary.simpleMessage("男性"),
    "uc_mose_over_thumb": MessageLookupByLibrary.simpleMessage("缩略图何时加载"),
    "uc_mpv": MessageLookupByLibrary.simpleMessage("多页查看器"),
    "uc_mpv_always": MessageLookupByLibrary.simpleMessage("总是使用"),
    "uc_mpv_stype": MessageLookupByLibrary.simpleMessage("显示样式"),
    "uc_mpv_thumb_pane": MessageLookupByLibrary.simpleMessage("缩略图侧栏"),
    "uc_ms_0": MessageLookupByLibrary.simpleMessage("左对齐\n仅当图像大于浏览器宽度时缩放"),
    "uc_ms_1": MessageLookupByLibrary.simpleMessage("居中对齐\n仅当图像大于浏览器宽度时缩放"),
    "uc_ms_2": MessageLookupByLibrary.simpleMessage("居中对齐\n始终缩放图像以适应浏览器宽度"),
    "uc_mt_0": MessageLookupByLibrary.simpleMessage("显示"),
    "uc_mt_1": MessageLookupByLibrary.simpleMessage("隐藏"),
    "uc_name_display": MessageLookupByLibrary.simpleMessage("图库的名字显示"),
    "uc_name_display_desc": MessageLookupByLibrary.simpleMessage(
      "很多图库都同时拥有英文或者日文标题，你想默认显示哪一个？",
    ),
    "uc_oi_0": MessageLookupByLibrary.simpleMessage("优先重新采样图像"),
    "uc_oi_1": MessageLookupByLibrary.simpleMessage("优先原图"),
    "uc_ori_image": MessageLookupByLibrary.simpleMessage("原始图像"),
    "uc_ori_image_desc": MessageLookupByLibrary.simpleMessage(
      "使用原始图像而不是重采样版本？如果您选择的水平分辨率不同于上述的 \"自动\"，且相关图像较宽，或者原始图像大于 10MB（一年以上的图库为 4MB），则仍将使用重采样图像。",
    ),
    "uc_parody": MessageLookupByLibrary.simpleMessage("原作"),
    "uc_pixels": MessageLookupByLibrary.simpleMessage("像素"),
    "uc_pn_0": MessageLookupByLibrary.simpleMessage("无"),
    "uc_pn_1": MessageLookupByLibrary.simpleMessage("仅页码"),
    "uc_pn_2": MessageLookupByLibrary.simpleMessage("页码 + 名称"),
    "uc_profile": MessageLookupByLibrary.simpleMessage("配置"),
    "uc_qb_0": MessageLookupByLibrary.simpleMessage("否"),
    "uc_qb_1": MessageLookupByLibrary.simpleMessage("是"),
    "uc_rating": MessageLookupByLibrary.simpleMessage("评分颜色"),
    "uc_rating_desc": MessageLookupByLibrary.simpleMessage(
      "默认设置下，你评为 2 星及以下的图库显示为红星，2.5 ~ 4 星显示为绿星，4.5 ~ 5 星显示为蓝星。你可以将其设定为其他颜色组合。\n每一个字幕代表一颗星, 默认的 RRGGB 表示第一第二颗星显示为红色 R(ed)，第三第四颗星显示是绿色 G(reen)，第五颗星显示为蓝色 B(lue)。你也可以使用黄色 (Y)ellow，R/G/B/Y 任何五个组合都是有效的。",
    ),
    "uc_reclass": MessageLookupByLibrary.simpleMessage("重新分类"),
    "uc_rename": MessageLookupByLibrary.simpleMessage("重命名"),
    "uc_res_res": MessageLookupByLibrary.simpleMessage("重新采样分辨率"),
    "uc_res_res_desc": MessageLookupByLibrary.simpleMessage(
      "图像通常会重新取样为 1280 像素的水平分辨率，以便在线查看。您可以选择以上分辨率。",
    ),
    "uc_sc_0": MessageLookupByLibrary.simpleMessage("悬停或点击时"),
    "uc_sc_1": MessageLookupByLibrary.simpleMessage("总是"),
    "uc_search_r_count": MessageLookupByLibrary.simpleMessage("搜索结果数"),
    "uc_search_r_count_desc": MessageLookupByLibrary.simpleMessage(
      "主页/搜索页面每页显示多少条数据？（Hath Perk：需要「页面扩大」）",
    ),
    "uc_selected": MessageLookupByLibrary.simpleMessage("当前"),
    "uc_set_as_def": MessageLookupByLibrary.simpleMessage("设为默认"),
    "uc_show_page_num": MessageLookupByLibrary.simpleMessage("缩略图标签"),
    "uc_tag": MessageLookupByLibrary.simpleMessage("图库标签"),
    "uc_tag_ft": MessageLookupByLibrary.simpleMessage("标签筛选阈值"),
    "uc_tag_ft_desc": MessageLookupByLibrary.simpleMessage(
      "你可以通过将标签加入「我的标签」并设置一个负权重来软过滤它们。如果一个作品所有的标签权重之和低于设定值，此作品将从视图中被过滤。这个值可以设定为 0 ~ -9999。",
    ),
    "uc_tag_namesp": MessageLookupByLibrary.simpleMessage("标签组"),
    "uc_tag_short_order": MessageLookupByLibrary.simpleMessage("图库标签排序"),
    "uc_tag_wt": MessageLookupByLibrary.simpleMessage("标签订阅阈值"),
    "uc_tag_wt_desc": MessageLookupByLibrary.simpleMessage(
      "你可以通过将标签加入「我的标签」并设置一个正权重来订阅它们。如果一个最近上传的作品所有标签的权重之和高于设定值，则它将会被包含在「订阅」里。这个值可以设定为 0 ~ 9999。",
    ),
    "uc_tb_0": MessageLookupByLibrary.simpleMessage("按字母排序"),
    "uc_tb_1": MessageLookupByLibrary.simpleMessage("按标签权重"),
    "uc_thor_hath": MessageLookupByLibrary.simpleMessage("通过H@H加载"),
    "uc_thumb_row": MessageLookupByLibrary.simpleMessage("行数"),
    "uc_thumb_scaling": MessageLookupByLibrary.simpleMessage("缩略图缩放"),
    "uc_thumb_scaling_desc": MessageLookupByLibrary.simpleMessage(
      "缩略图和扩展模式下的图库列表缩略图可以缩放为 75% 到 150% 之间的自定义值。",
    ),
    "uc_thumb_setting": MessageLookupByLibrary.simpleMessage("缩略图设置"),
    "uc_thumb_size": MessageLookupByLibrary.simpleMessage("大小"),
    "uc_tl_0": MessageLookupByLibrary.simpleMessage("默认标题"),
    "uc_tl_1": MessageLookupByLibrary.simpleMessage("日文标题（如果有）"),
    "uc_ts_0": MessageLookupByLibrary.simpleMessage("自动"),
    "uc_ts_1": MessageLookupByLibrary.simpleMessage("普通"),
    "uc_ts_2": MessageLookupByLibrary.simpleMessage("小图"),
    "uc_uh_0": MessageLookupByLibrary.simpleMessage("任意客户端（推荐）"),
    "uc_uh_0_s": MessageLookupByLibrary.simpleMessage("任意客户端"),
    "uc_uh_1": MessageLookupByLibrary.simpleMessage(
      "仅使用默认端口的客户端（可能稍慢。当防火墙或代理阻止非标准接口的流量时启用此项。）",
    ),
    "uc_uh_1_s": MessageLookupByLibrary.simpleMessage("仅使用默认端口的客户端"),
    "uc_uh_2": MessageLookupByLibrary.simpleMessage(
      "否 [现代/HTTPS]（仅限捐赠者。配额消耗会加快，只有出现严重的问题时才启用。）",
    ),
    "uc_uh_2_s": MessageLookupByLibrary.simpleMessage("否 [传统/HTTP]"),
    "uc_uh_3": MessageLookupByLibrary.simpleMessage(
      "否 [传统/HTTP]（仅限捐赠者。可能无法在现代浏览器中使用，只推荐在过时的浏览器中启用。）",
    ),
    "uc_uh_3_s": MessageLookupByLibrary.simpleMessage("否 [传统/HTTP]"),
    "uc_viewport_or": MessageLookupByLibrary.simpleMessage("移动端虚拟宽度"),
    "uc_viewport_or_desc": MessageLookupByLibrary.simpleMessage(
      "允许你覆盖移动设备的虚拟宽度，默认是根据 DPI 自动计算的，100% 缩略图比例下的合理值在 640 到 1400 之间。",
    ),
    "uc_xt_desc": MessageLookupByLibrary.simpleMessage(
      "如果要从默认标签搜索中排除某些标签组，可以检查以下内容。请注意，这不会阻止在这些标签组中的标签的展示区出现，它只是在搜索标签时排除这些标签组。",
    ),
    "unlimited": MessageLookupByLibrary.simpleMessage("不限制"),
    "update_to_version": m39,
    "upload_avatar": MessageLookupByLibrary.simpleMessage("上传头像"),
    "uploader": MessageLookupByLibrary.simpleMessage("上传者"),
    "user_login": MessageLookupByLibrary.simpleMessage("用户登录"),
    "user_name": MessageLookupByLibrary.simpleMessage("用户名"),
    "version": MessageLookupByLibrary.simpleMessage("版本"),
    "vibrate_feedback": MessageLookupByLibrary.simpleMessage("震动反馈"),
    "volume_key_turn_page": MessageLookupByLibrary.simpleMessage("音量键翻页"),
    "vote_down_successfully": MessageLookupByLibrary.simpleMessage("反对成功"),
    "vote_successfully": MessageLookupByLibrary.simpleMessage("投票成功"),
    "vote_up_successfully": MessageLookupByLibrary.simpleMessage("赞成成功"),
    "webdav_Account": MessageLookupByLibrary.simpleMessage("WebDAV账户"),
    "webdav_max_connections": MessageLookupByLibrary.simpleMessage(
      "WebDAV 最大连接数",
    ),
    "welcome_text": MessageLookupByLibrary.simpleMessage("小撸怡情~大撸伤身~强撸灰飞烟灭~~"),
  };
}
