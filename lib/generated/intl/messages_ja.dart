// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(count) => "${count} 列";

  static String m1(min, max) => "${min}〜${max} 列";

  static String m2(count) => "${count} 件";

  static String m3(page) => "続きから · ${page} ページ";

  static String m4(site) => "Current ${site}";

  static String m5(checked, total) => "更新を確認中 ${checked} / ${total}";

  static String m6(done, total) => "取得 ${done} / ${total}";

  static String m7(reused) => "一時停止 · ${reused} ページ再利用";

  static String m8(reused) => "更新中 · ${reused} ページ再利用";

  static String m9(checked, found, failed) =>
      "${checked} 件確認 · ${found} 件更新あり（${failed} 件失敗）";

  static String m10(count) => "${count} 件失敗";

  static String m11(count) => "${count} 件に新版あり";

  static String m12(count) => "すべて最新です · ${count} 件確認";

  static String m13(favcat) => "「${favcat}」に移動しました";

  static String m14(ok, fail) => "${ok} 件を移動、${fail} 件失敗";

  static String m15(ok, fail) => "${ok} 件を削除、${fail} 件失敗";

  static String m16(notes) => "${notes} 件のメモも同時に削除されます。元に戻せません。";

  static String m17(count) => "${count} 件をお気に入りから削除しますか？";

  static String m18(count) => "${count} 件のお気に入りを削除しました";

  static String m19(folder) => "既に「${folder}」に登録済み";

  static String m20(count) => "${count} 件のルールで使用中";

  static String m21(count) => "${count} 件";

  static String m22(category) => "「${category}」で新規ルール";

  static String m23(count) => "${count} 件";

  static String m24(count) => "履歴内の ${count} 件が一致";

  static String m25(count) => "履歴内の ${count} 件が一致";

  static String m26(count) => "${count} 回一致";

  static String m27(count, time) => "${count} 回一致 · 前回 ${time}";

  static String m28(count) => "${count} タグ一致";

  static String m29(folder) => "「${folder}」のまま維持しました";

  static String m30(folder) => "「${folder}」へ移動";

  static String m31(from, to) => "「${from}」から「${to}」へ移動しました";

  static String m32(rules) => "他にも「${rules}」が一致（優先順により未適用）";

  static String m33(rule) => "ルール「${rule}」";

  static String m34(rule, tag) => "ルール「${rule}」· ${tag}";

  static String m35(folder) => "「${folder}」へ保存";

  static String m36(folder) => "「${folder}」に保存しました";

  static String m37(count) => "オン · ${count} 件";

  static String m38(fallback) => "フォールバック動作: ${fallback}";

  static String m39(count) => "全 ${count} 件";

  static String m40(favcat) => "${favcat} に保存済み";

  static String m41(count, scope) => "${scope} で ${count} 件";

  static String m42(query, scope) => "${scope} に「${query}」は見つかりません";

  static String m43(favcat) => "${favcat} 内を検索";

  static String m44(count) => "${count} 件選択中";

  static String m45(favcat, total) => "${favcat} · ${total} 件";

  static String m46(count) => "${count} 件の評価";

  static String m47(count) => "全 ${count} バージョン";

  static String m48(count) => "親ギャラリーあり · 全 ${count} 件";

  static String m49(count) => "新しいバージョンが ${count} 件";

  static String m50(gid) => "現在のバージョン #${gid}";

  static String m51(value) => "ピーク ${value}";

  static String m52(value) => "期間平均 ${value}";

  static String m53(period, percent) => "${period} · ${percent}%";

  static String m54(value) => "期間合計 ${value}";

  static String m55(score) => "スコア ${score}";

  static String m56(date) => "${date} 更新";

  static String m57(count) => "追加 ${count}";

  static String m58(gid, reused) => "#${gid} へローカル更新完了（${reused} ページ再利用）";

  static String m59(count) => "${count} ページ取得";

  static String m60(count) => "改訂約 ${count}";

  static String m61(count) => "再利用 ${count} ページ";

  static String m62(reused, fetch) => "差分更新を開始しました（再利用 ${reused}、取得 ${fetch}）";

  static String m63(count) => "新版 全 ${count} ページ";

  static String m64(count) => "${count} 件のギャラリーのダウンロードが完了しました";

  static String m65(title) => "「${title}」のダウンロードが完了しました";

  static String m66(count) => "${count} 件のギャラリーをダウンロード中";

  static String m67(completed, total) => "${completed}/${total} ページ完了";

  static String m68(modelName) => "モデル${modelName}";

  static String m69(count) => "${count} ページ";

  static String m70(seconds) => "${seconds} 秒";

  static String m71(page, total) => "${page} / ${total} ページ";

  static String m72(rating) => "${rating} ⭐";

  static String m73(ok, total) => "${ok}/${total} 接続可能";

  static String m74(name) => "現在：${name}";

  static String m75(time) => "· ${time} 同期";

  static String m76(tag) => "${tag} を追加";

  static String m77(count) => "全 ${count} ページ";

  static String m78(avg, count) => "平均 ${avg} · ${count} 件";

  static String m79(text) => "「${text}」を検索";

  static String m80(count) => "${count} 件追加 · カンマ区切り";

  static String m81(count, per) => "全 ${count} ページ · 1ページ ${per} 枚";

  static String m82(count) => "トレント · ${count} 件";

  static String m83(tagNamespace) =>
      "${Intl.select(tagNamespace, {'reclass': 'reclass', 'language': 'language', 'parody': 'parody', 'character': 'character', 'group': 'group', 'artist': 'artist', 'male': 'male', 'female': 'female', 'mixed': 'mixed', 'cosplayer': 'cosplayer', 'other': 'other', 'temp': 'temp'})}";

  static String m84(version) => "アップデート利用可能！【${version}】";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "KEEP_IT_SAFE": MessageLookupByLibrary.simpleMessage("安全を確認してください"),
    "QR_code_block": MessageLookupByLibrary.simpleMessage("QRコードを含む画像をブロック"),
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "add_quick_search": MessageLookupByLibrary.simpleMessage("クイック検索に追加"),
    "add_tag_placeholder": MessageLookupByLibrary.simpleMessage(
      "新しいタグを入力してください（「,」で分別してください）",
    ),
    "add_tags": MessageLookupByLibrary.simpleMessage("タグに追加"),
    "add_to_favorites": MessageLookupByLibrary.simpleMessage("お気に入りに追加"),
    "add_to_phash_block_list": MessageLookupByLibrary.simpleMessage(
      "知覚ハッシュマスクリストに追加",
    ),
    "advanced": MessageLookupByLibrary.simpleMessage("その他"),
    "aggregate": MessageLookupByLibrary.simpleMessage("Aggregate"),
    "aggregate_groups": MessageLookupByLibrary.simpleMessage(
      "Aggregate groups",
    ),
    "all_Favorites": MessageLookupByLibrary.simpleMessage("総合"),
    "all_comment": MessageLookupByLibrary.simpleMessage("他のコメント"),
    "all_thumbnails": MessageLookupByLibrary.simpleMessage("サムネイル"),
    "allow_media_scan": MessageLookupByLibrary.simpleMessage("メディアスキャンを許可"),
    "always": MessageLookupByLibrary.simpleMessage("常時"),
    "app_title": MessageLookupByLibrary.simpleMessage("Eros-FE"),
    "appearance_and_layout": MessageLookupByLibrary.simpleMessage("外観とレイアウト"),
    "ask_me": MessageLookupByLibrary.simpleMessage("手動選択"),
    "auth_biometricHint": MessageLookupByLibrary.simpleMessage("本人確認"),
    "auth_signInTitle": MessageLookupByLibrary.simpleMessage("ログインが必要"),
    "author": MessageLookupByLibrary.simpleMessage("開発者"),
    "autoLock": MessageLookupByLibrary.simpleMessage("自動ロック"),
    "auto_scroll": MessageLookupByLibrary.simpleMessage("自動スクロール"),
    "auto_select_profile": MessageLookupByLibrary.simpleMessage("自動選択"),
    "automatic": MessageLookupByLibrary.simpleMessage("自動"),
    "avatar": MessageLookupByLibrary.simpleMessage("アバター"),
    "avatar_cf_verify_message": MessageLookupByLibrary.simpleMessage(
      "フォーラムは Cloudflare で保護されています。内蔵ブラウザで認証を完了すると、アップロードを自動的に再試行します。",
    ),
    "avatar_cf_verify_title": MessageLookupByLibrary.simpleMessage(
      "Cloudflare 認証が必要です",
    ),
    "avatar_from_album": MessageLookupByLibrary.simpleMessage("フォトライブラリ"),
    "avatar_from_file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "avatar_from_url": MessageLookupByLibrary.simpleMessage("画像 URL"),
    "avatar_local_success": MessageLookupByLibrary.simpleMessage("アバターを更新しました"),
    "avatar_source": MessageLookupByLibrary.simpleMessage("画像の取得元を選択"),
    "avatar_target": MessageLookupByLibrary.simpleMessage("アバターの使用先を選択"),
    "avatar_upload_success": MessageLookupByLibrary.simpleMessage(
      "アバターをアップロードしました",
    ),
    "avatar_use_forum": MessageLookupByLibrary.simpleMessage("EH フォーラムにアップロード"),
    "avatar_use_local": MessageLookupByLibrary.simpleMessage("この端末でのみ使用"),
    "back": MessageLookupByLibrary.simpleMessage("戻る"),
    "back_to_top": MessageLookupByLibrary.simpleMessage("トップへ戻る"),
    "block_rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "block_rules": MessageLookupByLibrary.simpleMessage("ブロックルール"),
    "blockers": MessageLookupByLibrary.simpleMessage("ブロッキング"),
    "blurring_cover_background": MessageLookupByLibrary.simpleMessage(
      "カバーの背景がぼやける",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "card_size": MessageLookupByLibrary.simpleMessage("カードのサイズ"),
    "card_size_footer": MessageLookupByLibrary.simpleMessage(
      "列数はリストがある欄の実際の幅で決まり、画面の切り替え、回転、仕切りのドラッグに合わせて自動で増減します。「標準」はこれまでの自動の列数と同じです。",
    ),
    "card_size_large": MessageLookupByLibrary.simpleMessage("大"),
    "card_size_larger": MessageLookupByLibrary.simpleMessage("やや大"),
    "card_size_small": MessageLookupByLibrary.simpleMessage("小"),
    "card_size_smaller": MessageLookupByLibrary.simpleMessage("やや小"),
    "card_size_standard": MessageLookupByLibrary.simpleMessage("標準"),
    "card_style": MessageLookupByLibrary.simpleMessage("カードスタイル"),
    "card_style_immersive": MessageLookupByLibrary.simpleMessage("イマーシブ"),
    "card_style_immersive_detail": MessageLookupByLibrary.simpleMessage(
      "表紙のみ。タイトルと評価を表紙に重ねて表示",
    ),
    "card_style_standard": MessageLookupByLibrary.simpleMessage("標準"),
    "card_style_standard_detail": MessageLookupByLibrary.simpleMessage(
      "表紙、タイトル、情報、タグ",
    ),
    "cf_verify_action": MessageLookupByLibrary.simpleMessage("認証する"),
    "cf_verify_prompt": MessageLookupByLibrary.simpleMessage(
      "フォーラムへのリクエストが Cloudflare にブロックされました。内蔵ブラウザで今すぐ認証しますか？",
    ),
    "cf_verify_required": MessageLookupByLibrary.simpleMessage("フォーラムの認証が必要です"),
    "cf_verify_still_blocked": MessageLookupByLibrary.simpleMessage(
      "認証は保存されましたが、フォーラムはまだブロックされています。しばらくしてから、またはネットワークを切り替えてから再試行してください。",
    ),
    "cf_verify_success": MessageLookupByLibrary.simpleMessage("認証が完了しました"),
    "cf_verify_summary": MessageLookupByLibrary.simpleMessage(
      "フォーラムへのリクエストがブロックされたときにアプリ内で再認証します",
    ),
    "cf_verify_title": MessageLookupByLibrary.simpleMessage("Cloudflare 認証"),
    "change_to_favorites": MessageLookupByLibrary.simpleMessage("お気に入りを移動"),
    "chapter": MessageLookupByLibrary.simpleMessage("章"),
    "check_download_files_and_continue": MessageLookupByLibrary.simpleMessage(
      "ファイルを確認して続行",
    ),
    "check_for_update": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "choose_favcat": MessageLookupByLibrary.simpleMessage("お気に入りフォルダを選択"),
    "clear_cache": MessageLookupByLibrary.simpleMessage("キャッシュを削除"),
    "clear_filter": MessageLookupByLibrary.simpleMessage("削除"),
    "clear_search_history": MessageLookupByLibrary.simpleMessage("検索履歴を全消去"),
    "clipboard_detection": MessageLookupByLibrary.simpleMessage("クリップボード検出"),
    "clipboard_detection_desc": MessageLookupByLibrary.simpleMessage(
      "リンクを自動検出",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("非表示"),
    "color_picker_primary": MessageLookupByLibrary.simpleMessage("Primary"),
    "color_picker_wheel": MessageLookupByLibrary.simpleMessage("Wheel"),
    "column_count": m0,
    "column_range": m1,
    "comment": MessageLookupByLibrary.simpleMessage("コメント"),
    "comment_count": m2,
    "commentator": MessageLookupByLibrary.simpleMessage("コメンター"),
    "concurrent_galleries": MessageLookupByLibrary.simpleMessage(
      "同時ギャラリーダウンロード数",
    ),
    "continue_reading_page": m3,
    "copied_to_clipboard": MessageLookupByLibrary.simpleMessage(
      "クリップボードにコピーしました",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copy_link": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copy_title": MessageLookupByLibrary.simpleMessage("タイトルをコピー"),
    "current_site": m4,
    "current_version": MessageLookupByLibrary.simpleMessage("バージョン番号"),
    "custom_hosts": MessageLookupByLibrary.simpleMessage("カスタムホスト"),
    "custom_width": MessageLookupByLibrary.simpleMessage("カスタム幅"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dark_mode_effect": MessageLookupByLibrary.simpleMessage("真っ黒モード"),
    "date_or_offset": MessageLookupByLibrary.simpleMessage("日付やオフセット"),
    "default_avatar_style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "delete_task": MessageLookupByLibrary.simpleMessage("タスクの削除"),
    "delete_task_and_content": MessageLookupByLibrary.simpleMessage(
      "タスクとコンテンツ",
    ),
    "delete_task_only": MessageLookupByLibrary.simpleMessage("タスクのみ"),
    "desktop_all_history": MessageLookupByLibrary.simpleMessage("すべての履歴を表示"),
    "desktop_clear_history_detail": MessageLookupByLibrary.simpleMessage(
      "この端末の閲覧履歴と最近読んだ作品を消去します。読書位置とダウンロードは保持されます。",
    ),
    "desktop_current_group": MessageLookupByLibrary.simpleMessage("現在のグループ"),
    "desktop_display_mode": MessageLookupByLibrary.simpleMessage("表示方法"),
    "desktop_follow_global": MessageLookupByLibrary.simpleMessage("全体設定に従う"),
    "desktop_global_mode": MessageLookupByLibrary.simpleMessage("全体の表示方法"),
    "desktop_global_mode_hint": MessageLookupByLibrary.simpleMessage(
      "全体設定に従う一覧にも適用",
    ),
    "desktop_hide_sidebar": MessageLookupByLibrary.simpleMessage("サイドバーを非表示"),
    "desktop_mode_sync_failed": MessageLookupByLibrary.simpleMessage(
      "表示形式を端末に保存しました。同期に失敗したため、接続を確認してください。",
    ),
    "desktop_no_groups": MessageLookupByLibrary.simpleMessage("グループなし"),
    "desktop_read_unavailable": MessageLookupByLibrary.simpleMessage(
      "作品を開けません。保存元を確認して再試行してください。",
    ),
    "desktop_recent_empty": MessageLookupByLibrary.simpleMessage(
      "読み始めた作品がここに表示されます。",
    ),
    "desktop_recent_reading": MessageLookupByLibrary.simpleMessage("最近読んだ作品"),
    "desktop_refresh": MessageLookupByLibrary.simpleMessage("現在の一覧を更新"),
    "desktop_refreshing": MessageLookupByLibrary.simpleMessage("一覧を更新中"),
    "desktop_resize_panes": MessageLookupByLibrary.simpleMessage("一覧と詳細の幅を調整"),
    "desktop_show_sidebar": MessageLookupByLibrary.simpleMessage("サイドバーを表示"),
    "desktop_untitled": MessageLookupByLibrary.simpleMessage("無題の作品"),
    "desktop_view_details": MessageLookupByLibrary.simpleMessage("詳細を表示"),
    "detail_ambient_background": MessageLookupByLibrary.simpleMessage(
      "詳細ページの背景",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disabled": MessageLookupByLibrary.simpleMessage("無効"),
    "domain_fronting": MessageLookupByLibrary.simpleMessage("Domain fronting"),
    "donate": MessageLookupByLibrary.simpleMessage("寄付金"),
    "done": MessageLookupByLibrary.simpleMessage("完了"),
    "double_click_back": MessageLookupByLibrary.simpleMessage("一度押して終了します"),
    "double_page_model": MessageLookupByLibrary.simpleMessage("両ページモード"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "download_check_updates": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "download_checking_updates_progress": m5,
    "download_files_unavailable": MessageLookupByLibrary.simpleMessage(
      "ファイルは一時的に利用できません",
    ),
    "download_filter_updatable": MessageLookupByLibrary.simpleMessage("新版のみ"),
    "download_has_update_badge": MessageLookupByLibrary.simpleMessage("新版あり"),
    "download_incremental_download_progress": m6,
    "download_incremental_failed_status": MessageLookupByLibrary.simpleMessage(
      "更新に失敗しました",
    ),
    "download_incremental_paused_status": m7,
    "download_incremental_status": m8,
    "download_incremental_updating": MessageLookupByLibrary.simpleMessage(
      "更新中",
    ),
    "download_location": MessageLookupByLibrary.simpleMessage("ダウンロードパス"),
    "download_ori_image": MessageLookupByLibrary.simpleMessage(
      "オリジナル画像をダウンロード",
    ),
    "download_ori_image_summary": MessageLookupByLibrary.simpleMessage(
      "危険です！509エラー発生可能性するがあります",
    ),
    "download_stop_check": MessageLookupByLibrary.simpleMessage("停止"),
    "download_update_action": MessageLookupByLibrary.simpleMessage("更新"),
    "download_update_all": MessageLookupByLibrary.simpleMessage("すべて更新"),
    "download_updates_checked_with_errors": m9,
    "download_updates_failed_count": m10,
    "download_updates_found": m11,
    "download_updates_no_targets": MessageLookupByLibrary.simpleMessage(
      "確認できる完了済みダウンロードがありません",
    ),
    "download_updates_none": m12,
    "downloaded": MessageLookupByLibrary.simpleMessage("ダウンロード済み"),
    "downloading": MessageLookupByLibrary.simpleMessage("ダウンロード中"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "edit_block_rule": MessageLookupByLibrary.simpleMessage("編集"),
    "edit_comment": MessageLookupByLibrary.simpleMessage("編集"),
    "eh": MessageLookupByLibrary.simpleMessage("E·H"),
    "ehentai_my_tags": MessageLookupByLibrary.simpleMessage("マイ タグ"),
    "ehentai_settings": MessageLookupByLibrary.simpleMessage("EHentai設定"),
    "enable": MessageLookupByLibrary.simpleMessage("有効化"),
    "english_title": MessageLookupByLibrary.simpleMessage("英語タイトル"),
    "enter_date_or_offset_or_gid": MessageLookupByLibrary.simpleMessage(
      "特定の日付やオフセット/GIDを入力",
    ),
    "expand": MessageLookupByLibrary.simpleMessage("表示"),
    "experimental_feature": MessageLookupByLibrary.simpleMessage(
      "Experimental feature",
    ),
    "export": MessageLookupByLibrary.simpleMessage("エクスポート"),
    "export_app_data": MessageLookupByLibrary.simpleMessage("データをエクスポート"),
    "export_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "データを外部ストレージにエクスポートしてバックアップ",
    ),
    "fav_batch_working": MessageLookupByLibrary.simpleMessage("処理中…"),
    "fav_current": MessageLookupByLibrary.simpleMessage("現在"),
    "fav_deselect_all": MessageLookupByLibrary.simpleMessage("選択解除"),
    "fav_move_to": MessageLookupByLibrary.simpleMessage("移動先…"),
    "fav_moved_to": m13,
    "fav_note_add": MessageLookupByLibrary.simpleMessage("メモを追加"),
    "fav_note_edit": MessageLookupByLibrary.simpleMessage("メモを編集"),
    "fav_partial_failed": m14,
    "fav_partial_remove_failed": m15,
    "fav_remove_irreversible": MessageLookupByLibrary.simpleMessage(
      "この操作は元に戻せません。",
    ),
    "fav_remove_note_warn": m16,
    "fav_remove_title": m17,
    "fav_removed_count": m18,
    "fav_rule_add_condition": MessageLookupByLibrary.simpleMessage("条件を追加"),
    "fav_rule_already_in_folder": m19,
    "fav_rule_category_badge": MessageLookupByLibrary.simpleMessage("カテゴリ"),
    "fav_rule_category_used_count": m20,
    "fav_rule_change_folder": MessageLookupByLibrary.simpleMessage("変更"),
    "fav_rule_clear_selection": MessageLookupByLibrary.simpleMessage("クリア"),
    "fav_rule_conditions": MessageLookupByLibrary.simpleMessage("条件"),
    "fav_rule_count_items": m21,
    "fav_rule_create_by_category": m22,
    "fav_rule_create_from_gallery": MessageLookupByLibrary.simpleMessage(
      "このギャラリーから新規ルール",
    ),
    "fav_rule_create_from_tag_short": MessageLookupByLibrary.simpleMessage(
      "新規ルール",
    ),
    "fav_rule_delete_condition": MessageLookupByLibrary.simpleMessage("条件を削除"),
    "fav_rule_delete_confirm": MessageLookupByLibrary.simpleMessage(
      "このお気に入りルールを削除しますか？",
    ),
    "fav_rule_delete_title": MessageLookupByLibrary.simpleMessage("ルールを削除"),
    "fav_rule_edit_condition": MessageLookupByLibrary.simpleMessage("条件を編集"),
    "fav_rule_edit_title": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "fav_rule_enable": MessageLookupByLibrary.simpleMessage("ルールお気に入りを有効にする"),
    "fav_rule_enable_desc": MessageLookupByLibrary.simpleMessage(
      "一致したルールのフォルダへワンステップで保存",
    ),
    "fav_rule_entry_desc": MessageLookupByLibrary.simpleMessage(
      "お気に入り登録時にタグ・カテゴリで振り分け",
    ),
    "fav_rule_existing": MessageLookupByLibrary.simpleMessage("既にお気に入り登録済みの場合"),
    "fav_rule_existing_keep": MessageLookupByLibrary.simpleMessage(
      "現在のフォルダを維持",
    ),
    "fav_rule_existing_move": MessageLookupByLibrary.simpleMessage("一致フォルダへ移動"),
    "fav_rule_fallback": MessageLookupByLibrary.simpleMessage("一致するルールがない場合"),
    "fav_rule_fallback_fixed": MessageLookupByLibrary.simpleMessage(
      "固定フォルダに保存",
    ),
    "fav_rule_fallback_folder": MessageLookupByLibrary.simpleMessage("固定フォルダ"),
    "fav_rule_fallback_last": MessageLookupByLibrary.simpleMessage(
      "前回のフォルダに保存",
    ),
    "fav_rule_fallback_picker": MessageLookupByLibrary.simpleMessage(
      "フォルダ選択を表示",
    ),
    "fav_rule_fetch_tags_failed": MessageLookupByLibrary.simpleMessage(
      "タグを取得できませんでした",
    ),
    "fav_rule_gallery_count": m23,
    "fav_rule_history_empty_save_ok": MessageLookupByLibrary.simpleMessage(
      "履歴に一致する作品はまだありませんが、保存後は通常どおり有効になります。",
    ),
    "fav_rule_history_hits_count": m24,
    "fav_rule_history_hits_empty": MessageLookupByLibrary.simpleMessage(
      "履歴に一致するギャラリーはありません。",
    ),
    "fav_rule_history_hits_matched": m25,
    "fav_rule_hit_stats": m26,
    "fav_rule_hit_stats_with_time": m27,
    "fav_rule_hit_tag_count": m28,
    "fav_rule_invalid_condition": MessageLookupByLibrary.simpleMessage(
      "無効な条件または正規表現が含まれています",
    ),
    "fav_rule_invalid_regex": MessageLookupByLibrary.simpleMessage("正規表現が無効です"),
    "fav_rule_kept_in_folder": m29,
    "fav_rule_last_used_badge": MessageLookupByLibrary.simpleMessage("前回"),
    "fav_rule_list_footer": MessageLookupByLibrary.simpleMessage(
      "長押しで並び替え、左スワイプで削除。",
    ),
    "fav_rule_list_menu_context": MessageLookupByLibrary.simpleMessage(
      "フローティングメニュー",
    ),
    "fav_rule_list_menu_sheet": MessageLookupByLibrary.simpleMessage(
      "ボトムアクションシート",
    ),
    "fav_rule_list_menu_style": MessageLookupByLibrary.simpleMessage(
      "リスト長押しメニュー",
    ),
    "fav_rule_match_all": MessageLookupByLibrary.simpleMessage("すべてに一致"),
    "fav_rule_match_any": MessageLookupByLibrary.simpleMessage("いずれかに一致"),
    "fav_rule_match_op": MessageLookupByLibrary.simpleMessage("一致方法"),
    "fav_rule_match_translation_hint": MessageLookupByLibrary.simpleMessage(
      "翻訳タグ名も照合する",
    ),
    "fav_rule_matched_known_tags": MessageLookupByLibrary.simpleMessage(
      "一致する既知タグ",
    ),
    "fav_rule_matching_tags": MessageLookupByLibrary.simpleMessage("ルールを照合中…"),
    "fav_rule_migrated_desc": MessageLookupByLibrary.simpleMessage(
      "従来のタップ保存動作は引き継がれています。タグルールを追加して自動分類できます。",
    ),
    "fav_rule_migrated_title": MessageLookupByLibrary.simpleMessage(
      "ワンステップお気に入りをルールお気に入りに移行しました",
    ),
    "fav_rule_miss_saved_fixed": MessageLookupByLibrary.simpleMessage(
      "ルール不一致 · 固定フォルダに保存",
    ),
    "fav_rule_miss_saved_last": MessageLookupByLibrary.simpleMessage(
      "ルール不一致 · 前回のフォルダに保存",
    ),
    "fav_rule_miss_title": MessageLookupByLibrary.simpleMessage(
      "一致するルールがありません",
    ),
    "fav_rule_mode_category": MessageLookupByLibrary.simpleMessage("カテゴリ"),
    "fav_rule_mode_tag": MessageLookupByLibrary.simpleMessage("タグ"),
    "fav_rule_move_to_folder": m30,
    "fav_rule_moved_folder": m31,
    "fav_rule_my_tags_short": MessageLookupByLibrary.simpleMessage("マイタグ"),
    "fav_rule_name_placeholder": MessageLookupByLibrary.simpleMessage(
      "ルール名（空欄なら自動生成）",
    ),
    "fav_rule_namespace_any": MessageLookupByLibrary.simpleMessage("すべて"),
    "fav_rule_namespace_more": MessageLookupByLibrary.simpleMessage("その他"),
    "fav_rule_need_condition": MessageLookupByLibrary.simpleMessage(
      "条件を1つ以上追加してください",
    ),
    "fav_rule_new_subtitle": MessageLookupByLibrary.simpleMessage(
      "新規ルール · 名前は省略可",
    ),
    "fav_rule_new_title": MessageLookupByLibrary.simpleMessage("新規ルール"),
    "fav_rule_no_hits_yet": MessageLookupByLibrary.simpleMessage(
      "まだ一致履歴がありません",
    ),
    "fav_rule_no_known_tag_matches": MessageLookupByLibrary.simpleMessage(
      "一致する既知タグはありませんが、そのまま保存できます。",
    ),
    "fav_rule_no_tag_db_hint": MessageLookupByLibrary.simpleMessage(
      "タグ翻訳データベースが未取得のためプレビューできません（ルール判定自体は動作します）。",
    ),
    "fav_rule_op_contains": MessageLookupByLibrary.simpleMessage("部分一致"),
    "fav_rule_op_equals": MessageLookupByLibrary.simpleMessage("完全一致"),
    "fav_rule_op_regex": MessageLookupByLibrary.simpleMessage("正規表現"),
    "fav_rule_order_hint": MessageLookupByLibrary.simpleMessage(
      "上から順に評価し最初に一致したものを適用",
    ),
    "fav_rule_other_hits_note": m32,
    "fav_rule_pick_one_folder_hint": MessageLookupByLibrary.simpleMessage(
      "フォルダを選択",
    ),
    "fav_rule_picker_grid": MessageLookupByLibrary.simpleMessage("カラーグリッド"),
    "fav_rule_picker_list": MessageLookupByLibrary.simpleMessage("クラシックリスト"),
    "fav_rule_picker_style": MessageLookupByLibrary.simpleMessage("フォルダ選択スタイル"),
    "fav_rule_picker_switched": MessageLookupByLibrary.simpleMessage(
      "スタイルを切り替えました",
    ),
    "fav_rule_picker_wheel": MessageLookupByLibrary.simpleMessage("ホイールピッカー"),
    "fav_rule_preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "fav_rule_reason_only": m33,
    "fav_rule_reason_with_tag": m34,
    "fav_rule_regex_placeholder": MessageLookupByLibrary.simpleMessage(
      "正規表現を入力 (例: ^foot.*)",
    ),
    "fav_rule_remember_action": MessageLookupByLibrary.simpleMessage("記憶する"),
    "fav_rule_remember_created_title": MessageLookupByLibrary.simpleMessage(
      "ルールを作成しました",
    ),
    "fav_rule_save_into_lead": MessageLookupByLibrary.simpleMessage("保存先"),
    "fav_rule_save_to_folder": m35,
    "fav_rule_saved_to_folder": m36,
    "fav_rule_search_this_category": MessageLookupByLibrary.simpleMessage(
      "このカテゴリを検索",
    ),
    "fav_rule_section_rules": MessageLookupByLibrary.simpleMessage("ルール"),
    "fav_rule_section_trigger": MessageLookupByLibrary.simpleMessage(
      "トリガーとフォールバック",
    ),
    "fav_rule_section_ui_style": MessageLookupByLibrary.simpleMessage(
      "パネルスタイル",
    ),
    "fav_rule_select_category": MessageLookupByLibrary.simpleMessage("カテゴリを選択"),
    "fav_rule_status_disabled": MessageLookupByLibrary.simpleMessage("オフ"),
    "fav_rule_status_enabled": MessageLookupByLibrary.simpleMessage("オン"),
    "fav_rule_status_enabled_count": m37,
    "fav_rule_tag_namespace": MessageLookupByLibrary.simpleMessage("タグ種別"),
    "fav_rule_target_folder": MessageLookupByLibrary.simpleMessage("保存先"),
    "fav_rule_test_custom_tags": MessageLookupByLibrary.simpleMessage(
      "タグを手動入力",
    ),
    "fav_rule_test_fallback_desc": m38,
    "fav_rule_test_from_history": MessageLookupByLibrary.simpleMessage(
      "履歴から選択",
    ),
    "fav_rule_test_input_label": MessageLookupByLibrary.simpleMessage(
      "テストタグ（カンマまたは改行区切り）",
    ),
    "fav_rule_test_input_placeholder": MessageLookupByLibrary.simpleMessage(
      "例: artist:mitsuki, female:foot focus",
    ),
    "fav_rule_test_no_history": MessageLookupByLibrary.simpleMessage(
      "履歴がありません。「タグを手動入力」でテストできます。",
    ),
    "fav_rule_test_pick_gallery": MessageLookupByLibrary.simpleMessage(
      "ギャラリーを選んでルール順をテスト",
    ),
    "fav_rule_test_title": MessageLookupByLibrary.simpleMessage("ルールテスト"),
    "fav_rule_title": MessageLookupByLibrary.simpleMessage("ルールお気に入り"),
    "fav_rule_total_count": m39,
    "fav_rule_trigger": MessageLookupByLibrary.simpleMessage("トリガー操作"),
    "fav_rule_trigger_long_press": MessageLookupByLibrary.simpleMessage(
      "お気に入りボタンを長押し",
    ),
    "fav_rule_trigger_tap": MessageLookupByLibrary.simpleMessage(
      "お気に入りボタンをタップ",
    ),
    "fav_rule_type_to_preview_tags": MessageLookupByLibrary.simpleMessage(
      "キーワードを入力すると一致するタグを表示します。",
    ),
    "fav_rule_undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "fav_rule_value_placeholder": MessageLookupByLibrary.simpleMessage(
      "タグまたはキーワードを入力",
    ),
    "fav_saved_in": m40,
    "fav_scope_all": MessageLookupByLibrary.simpleMessage("すべて"),
    "fav_scope_note": MessageLookupByLibrary.simpleMessage("メモ"),
    "fav_scope_tag": MessageLookupByLibrary.simpleMessage("タグ"),
    "fav_scope_title": MessageLookupByLibrary.simpleMessage("タイトル"),
    "fav_search_all_fields": MessageLookupByLibrary.simpleMessage("すべての項目から検索"),
    "fav_search_all_folders": MessageLookupByLibrary.simpleMessage(
      "すべてのお気に入りから検索",
    ),
    "fav_search_count": m41,
    "fav_search_empty": m42,
    "fav_search_in": m43,
    "fav_select": MessageLookupByLibrary.simpleMessage("選択"),
    "fav_selected_count": m44,
    "fav_selected_scope": m45,
    "favcat": MessageLookupByLibrary.simpleMessage("お気に入り"),
    "favorite_note_hint": MessageLookupByLibrary.simpleMessage("メモ（任意）"),
    "favorites_order": MessageLookupByLibrary.simpleMessage("お気に入り並べ替え"),
    "favorites_order_Use_favorited": MessageLookupByLibrary.simpleMessage(
      "お気に入り日付順",
    ),
    "favorites_order_Use_posted": MessageLookupByLibrary.simpleMessage(
      "アップロードされた日付順",
    ),
    "file_size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "filter_by_uploader": MessageLookupByLibrary.simpleMessage("アップローダーで絞り込む"),
    "filter_comments_by_score": MessageLookupByLibrary.simpleMessage(
      "スコアでくコメントを絞り込む",
    ),
    "filter_comments_by_score_summary": MessageLookupByLibrary.simpleMessage(
      "このスコア以下のコメントは表示されません",
    ),
    "fixed_height_of_list_items": MessageLookupByLibrary.simpleMessage(
      "リスト項目の高さを固定",
    ),
    "follow_system": MessageLookupByLibrary.simpleMessage("システム設定"),
    "full_title": MessageLookupByLibrary.simpleMessage("完全なタイトル"),
    "full_title_in_gallery": MessageLookupByLibrary.simpleMessage("完全なタイトルを表示"),
    "full_title_in_gallery_subtitle": MessageLookupByLibrary.simpleMessage(
      "一覧とギャラリーページで別言語のタイトルを改行して表示",
    ),
    "fullscreen": MessageLookupByLibrary.simpleMessage("フルスクリーン"),
    "galery_site": MessageLookupByLibrary.simpleMessage("ギャラリーサイト"),
    "gallery_comments": MessageLookupByLibrary.simpleMessage("コメント"),
    "gallery_downloaded_has_update": MessageLookupByLibrary.simpleMessage(
      "ダウンロード済み、新しいバージョンあり",
    ),
    "gallery_info": MessageLookupByLibrary.simpleMessage("ギャラリー情報"),
    "gallery_info_category": MessageLookupByLibrary.simpleMessage("カテゴリ"),
    "gallery_info_cover_url": MessageLookupByLibrary.simpleMessage("カバー URL"),
    "gallery_info_expunged": MessageLookupByLibrary.simpleMessage("削除済み"),
    "gallery_info_favorite_status": MessageLookupByLibrary.simpleMessage(
      "お気に入り",
    ),
    "gallery_info_gallery_url": MessageLookupByLibrary.simpleMessage(
      "ギャラリー URL",
    ),
    "gallery_info_open_browser": MessageLookupByLibrary.simpleMessage(
      "ブラウザで開く",
    ),
    "gallery_info_open_browser_failed": MessageLookupByLibrary.simpleMessage(
      "ブラウザでリンクを開けませんでした",
    ),
    "gallery_info_posted": MessageLookupByLibrary.simpleMessage("投稿日時"),
    "gallery_info_rating_votes": m46,
    "gallery_info_section_details": MessageLookupByLibrary.simpleMessage(
      "詳細情報",
    ),
    "gallery_info_section_identifiers": MessageLookupByLibrary.simpleMessage(
      "識別子とリンク",
    ),
    "gallery_info_section_titles": MessageLookupByLibrary.simpleMessage("タイトル"),
    "gallery_info_visible": MessageLookupByLibrary.simpleMessage("公開状態"),
    "gallery_latest_version": MessageLookupByLibrary.simpleMessage("最新"),
    "gallery_lineage": MessageLookupByLibrary.simpleMessage("バージョン履歴"),
    "gallery_lineage_copy_hint": MessageLookupByLibrary.simpleMessage(
      "タップで開く · 長押しでリンクをコピー",
    ),
    "gallery_lineage_count": m47,
    "gallery_lineage_current": MessageLookupByLibrary.simpleMessage("現在"),
    "gallery_lineage_from_parent": m48,
    "gallery_lineage_newer": MessageLookupByLibrary.simpleMessage("新しいバージョン"),
    "gallery_metadata": MessageLookupByLibrary.simpleMessage("メタデータ"),
    "gallery_newer_version_count": m49,
    "gallery_newer_version_single": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンあり",
    ),
    "gallery_newer_versions": MessageLookupByLibrary.simpleMessage("新しいバージョン"),
    "gallery_open_latest_version": MessageLookupByLibrary.simpleMessage(
      "最新バージョンを開く",
    ),
    "gallery_open_parent": MessageLookupByLibrary.simpleMessage("親ギャラリーを開く"),
    "gallery_parent": MessageLookupByLibrary.simpleMessage("親ギャラリー"),
    "gallery_parent_none": MessageLookupByLibrary.simpleMessage("なし"),
    "gallery_parent_unavailable": MessageLookupByLibrary.simpleMessage("利用不可"),
    "gallery_stats": MessageLookupByLibrary.simpleMessage("ギャラリー統計"),
    "gallery_stats_all_time": MessageLookupByLibrary.simpleMessage("全期間"),
    "gallery_stats_collapse": MessageLookupByLibrary.simpleMessage("閉じる"),
    "gallery_stats_current_version": m50,
    "gallery_stats_daily": MessageLookupByLibrary.simpleMessage("日別"),
    "gallery_stats_daily_avg": MessageLookupByLibrary.simpleMessage("日平均"),
    "gallery_stats_empty_body": MessageLookupByLibrary.simpleMessage(
      "E-Hentai の stats.php はアカウント権限（寄付・投稿者など）やギャラリーの状態により閲覧できない場合があります。",
    ),
    "gallery_stats_empty_title": MessageLookupByLibrary.simpleMessage(
      "統計データを表示できません",
    ),
    "gallery_stats_expand_action": MessageLookupByLibrary.simpleMessage(
      "ギャラリー統計を読み込む",
    ),
    "gallery_stats_expand_hint": MessageLookupByLibrary.simpleMessage(
      "必要に応じて stats.php を取得（アカウント権限に依存）",
    ),
    "gallery_stats_fav_rate": MessageLookupByLibrary.simpleMessage("お気に入り率"),
    "gallery_stats_hits": MessageLookupByLibrary.simpleMessage("ヒット数"),
    "gallery_stats_load_failed": MessageLookupByLibrary.simpleMessage(
      "ギャラリー統計の取得に失敗しました",
    ),
    "gallery_stats_loading": MessageLookupByLibrary.simpleMessage(
      "統計データを読み込み中…",
    ),
    "gallery_stats_login_required": MessageLookupByLibrary.simpleMessage(
      "ギャラリー統計を表示するには E-Hentai へのログインが必要です",
    ),
    "gallery_stats_monthly": MessageLookupByLibrary.simpleMessage("月別"),
    "gallery_stats_no_rankings": MessageLookupByLibrary.simpleMessage(
      "現在ランキング圏外です",
    ),
    "gallery_stats_no_series_data": MessageLookupByLibrary.simpleMessage(
      "この期間の履歴データはありません",
    ),
    "gallery_stats_open_web": MessageLookupByLibrary.simpleMessage(
      "stats.php を開く",
    ),
    "gallery_stats_past_month": MessageLookupByLibrary.simpleMessage("過去1か月"),
    "gallery_stats_past_year": MessageLookupByLibrary.simpleMessage("過去1年"),
    "gallery_stats_peak": m51,
    "gallery_stats_period_avg": m52,
    "gallery_stats_period_share": m53,
    "gallery_stats_period_total": m54,
    "gallery_stats_ranking": MessageLookupByLibrary.simpleMessage("ランキング"),
    "gallery_stats_refresh": MessageLookupByLibrary.simpleMessage("統計を更新"),
    "gallery_stats_retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "gallery_stats_score": m55,
    "gallery_stats_total_visits": MessageLookupByLibrary.simpleMessage("総閲覧数"),
    "gallery_stats_unranked": MessageLookupByLibrary.simpleMessage("圏外"),
    "gallery_stats_visits": MessageLookupByLibrary.simpleMessage("閲覧数"),
    "gallery_stats_yearly": MessageLookupByLibrary.simpleMessage("年別"),
    "gallery_stats_yesterday": MessageLookupByLibrary.simpleMessage("昨日"),
    "gallery_updatable_hint": MessageLookupByLibrary.simpleMessage("差分更新可"),
    "gallery_updated_on": m56,
    "glass_effect": MessageLookupByLibrary.simpleMessage("ガラス効果"),
    "glass_material": MessageLookupByLibrary.simpleMessage("ガラスの素材"),
    "glass_material_frosted": MessageLookupByLibrary.simpleMessage("すりガラス"),
    "glass_material_frosted_detail": MessageLookupByLibrary.simpleMessage(
      "やわらかなぼかし。動作が軽い",
    ),
    "glass_material_liquid": MessageLookupByLibrary.simpleMessage("リキッドガラス"),
    "glass_material_liquid_detail": MessageLookupByLibrary.simpleMessage(
      "屈折とハイライト。消費電力が多め",
    ),
    "glass_system_bar_note": MessageLookupByLibrary.simpleMessage(
      "システムが描画する縦向きのタブバー（iPhone Duo の外側ディスプレイのサイドバーなど）は常にリキッドガラスです。",
    ),
    "global_setting": MessageLookupByLibrary.simpleMessage("通常"),
    "gray_black": MessageLookupByLibrary.simpleMessage("灰色"),
    "group": MessageLookupByLibrary.simpleMessage("総合"),
    "groupName": MessageLookupByLibrary.simpleMessage("名前"),
    "groupType": MessageLookupByLibrary.simpleMessage("タイプ"),
    "group_management": MessageLookupByLibrary.simpleMessage("グループ管理"),
    "hide": MessageLookupByLibrary.simpleMessage("非表示"),
    "hide_gallery_thumbnails": MessageLookupByLibrary.simpleMessage(
      "サムネイル（非表示）",
    ),
    "hide_thumbnails": MessageLookupByLibrary.simpleMessage("サムネイル（非表示）"),
    "hide_top_bar_on_scroll": MessageLookupByLibrary.simpleMessage(
      "スクロール時にトップバーを隠す",
    ),
    "high_resolution_images_limited": MessageLookupByLibrary.simpleMessage(
      "High Resolution Images Limited",
    ),
    "horizontal_thumbnails": MessageLookupByLibrary.simpleMessage("水平サムネイル"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "image_block": MessageLookupByLibrary.simpleMessage("画像ブロッキング"),
    "image_download_type": MessageLookupByLibrary.simpleMessage("ダウンロードタイプ"),
    "image_limits": MessageLookupByLibrary.simpleMessage("画像制限"),
    "image_save_busy": MessageLookupByLibrary.simpleMessage("画像を保存中です。"),
    "image_save_download": MessageLookupByLibrary.simpleMessage(
      "画像をダウンロードできませんでした。もう一度お試しください。",
    ),
    "image_save_invalid": MessageLookupByLibrary.simpleMessage(
      "画像ファイルが存在しないか、不完全または無効です。",
    ),
    "image_save_permission": MessageLookupByLibrary.simpleMessage(
      "写真の追加が許可されていません。システム設定で許可してください。LiveContainer を使用している場合は、その写真へのアクセス権を確認してください。",
    ),
    "image_save_unsupported": MessageLookupByLibrary.simpleMessage(
      "写真ライブラリはこの画像形式に対応していません。",
    ),
    "image_save_write": MessageLookupByLibrary.simpleMessage(
      "写真ライブラリに保存できませんでした。もう一度お試しください。",
    ),
    "import_app_data": MessageLookupByLibrary.simpleMessage("データをインポート"),
    "import_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "バックアップからインポート、再起動の必要があります",
    ),
    "import_export": MessageLookupByLibrary.simpleMessage("インポートとエクスポート"),
    "incremental_update_added": MessageLookupByLibrary.simpleMessage("追加ページ"),
    "incremental_update_added_pages": m57,
    "incremental_update_all_reused": MessageLookupByLibrary.simpleMessage(
      "全ページをローカル再利用可能",
    ),
    "incremental_update_applying": MessageLookupByLibrary.simpleMessage(
      "更新を適用中…",
    ),
    "incremental_update_cannot_reuse": MessageLookupByLibrary.simpleMessage(
      "再利用不可",
    ),
    "incremental_update_compare_failed": MessageLookupByLibrary.simpleMessage(
      "新バージョンの比較に失敗しました",
    ),
    "incremental_update_comparing": MessageLookupByLibrary.simpleMessage(
      "新版ページを比較中…",
    ),
    "incremental_update_completed_locally": m58,
    "incremental_update_entry": MessageLookupByLibrary.simpleMessage(
      "ダウンロード済みギャラリーを差分更新",
    ),
    "incremental_update_mode_inplace": MessageLookupByLibrary.simpleMessage(
      "置換",
    ),
    "incremental_update_mode_inplace_desc":
        MessageLookupByLibrary.simpleMessage("旧版フォルダを新版に置き換え、読書位置を自動で引き継ぎます。"),
    "incremental_update_mode_new": MessageLookupByLibrary.simpleMessage(
      "残して新規保存",
    ),
    "incremental_update_mode_new_desc": MessageLookupByLibrary.simpleMessage(
      "未変更ページを再利用して新規タスクを作成し、旧版を残します。",
    ),
    "incremental_update_mode_new_saf_desc":
        MessageLookupByLibrary.simpleMessage("新規タスクとして全ページを取得し、旧版をそのまま残します。"),
    "incremental_update_need_download": m59,
    "incremental_update_old_version": MessageLookupByLibrary.simpleMessage(
      "旧バージョン",
    ),
    "incremental_update_replaced_approx": m60,
    "incremental_update_reused": MessageLookupByLibrary.simpleMessage("再利用"),
    "incremental_update_reused_pages": m61,
    "incremental_update_saf_inplace_unsupported":
        MessageLookupByLibrary.simpleMessage(
          "SAF ストレージはローカル再利用・上書き更新に未対応のため、新規タスクとして全ページ取得します。",
        ),
    "incremental_update_saf_short_note": MessageLookupByLibrary.simpleMessage(
      "現在の SAF 保存先ではローカル再利用できません",
    ),
    "incremental_update_start": MessageLookupByLibrary.simpleMessage("更新を開始"),
    "incremental_update_start_reuse_only": MessageLookupByLibrary.simpleMessage(
      "今すぐ更新を完了",
    ),
    "incremental_update_start_saf_full": MessageLookupByLibrary.simpleMessage(
      "新版をすべて取得",
    ),
    "incremental_update_started": m62,
    "incremental_update_subtitle": MessageLookupByLibrary.simpleMessage(
      "未変更のローカルページを再利用",
    ),
    "incremental_update_target_version": MessageLookupByLibrary.simpleMessage(
      "更新先バージョン",
    ),
    "incremental_update_title": MessageLookupByLibrary.simpleMessage(
      "ダウンロード済みギャラリーを更新",
    ),
    "incremental_update_to_latest": MessageLookupByLibrary.simpleMessage(
      "最新版へ差分更新",
    ),
    "incremental_update_total_pages": m63,
    "incremental_update_view_newer": MessageLookupByLibrary.simpleMessage(
      "新バージョンの詳細を見る",
    ),
    "inner_display": MessageLookupByLibrary.simpleMessage("内側ディスプレイ"),
    "input_empty": MessageLookupByLibrary.simpleMessage("入力は空です"),
    "input_error": MessageLookupByLibrary.simpleMessage("入力エラー"),
    "instantly": MessageLookupByLibrary.simpleMessage("即刻"),
    "ios_bg_download": MessageLookupByLibrary.simpleMessage("バックグラウンドダウンロード"),
    "ios_bg_download_complete_multi": m64,
    "ios_bg_download_complete_single": m65,
    "ios_bg_download_complete_title": MessageLookupByLibrary.simpleMessage(
      "ダウンロード完了",
    ),
    "ios_bg_download_multi_title": m66,
    "ios_bg_download_notify": MessageLookupByLibrary.simpleMessage(
      "ダウンロード完了通知",
    ),
    "ios_bg_download_notify_subtitle": MessageLookupByLibrary.simpleMessage(
      "バックグラウンドダウンロード完了時にローカル通知でお知らせします",
    ),
    "ios_bg_download_progress_pages": m67,
    "ios_bg_download_subtitle": MessageLookupByLibrary.simpleMessage(
      "音楽再生を中断せずにバックグラウンドでギャラリーのダウンロードを継続します",
    ),
    "japanese_title": MessageLookupByLibrary.simpleMessage("日本語タイトル"),
    "japanese_title_in_gallery": MessageLookupByLibrary.simpleMessage(
      "日本語のタイトル",
    ),
    "japanese_title_in_gallery_summary": MessageLookupByLibrary.simpleMessage(
      "日本語のタイトルはギャラリーページのみ",
    ),
    "jump_next": MessageLookupByLibrary.simpleMessage("次"),
    "jump_or_seek": MessageLookupByLibrary.simpleMessage("日付に飛び込む"),
    "jump_prev": MessageLookupByLibrary.simpleMessage("前"),
    "jump_to_page": MessageLookupByLibrary.simpleMessage("転移"),
    "landscape": MessageLookupByLibrary.simpleMessage("横向き"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "last_favorites": MessageLookupByLibrary.simpleMessage("最後のお気に入り、長押しで手動選択"),
    "latest_version": MessageLookupByLibrary.simpleMessage("新しいバージョンがありません"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "left_to_right": MessageLookupByLibrary.simpleMessage("左から右"),
    "license": MessageLookupByLibrary.simpleMessage("オープンソースライセンス"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "link_redirect": MessageLookupByLibrary.simpleMessage("Link redirect"),
    "link_redirect_summary": MessageLookupByLibrary.simpleMessage(
      "Redirecting gallery links to selected sites",
    ),
    "liquid_glass_description": MessageLookupByLibrary.simpleMessage(
      "ナビゲーションバー、タブバー、ボタン、メニューにガラス効果を使用します。すりガラスは消費電力が少なく、スクロールも滑らかです。",
    ),
    "liquid_glass_inline": MessageLookupByLibrary.simpleMessage("コンパクトな1行"),
    "liquid_glass_inline_detail": MessageLookupByLibrary.simpleMessage(
      "操作とカテゴリを1行に表示",
    ),
    "liquid_glass_top_layout": MessageLookupByLibrary.simpleMessage(
      "上部カテゴリの配置",
    ),
    "liquid_glass_two_row": MessageLookupByLibrary.simpleMessage("2行（デフォルト）"),
    "liquid_glass_two_row_detail": MessageLookupByLibrary.simpleMessage(
      "操作とカテゴリを別々の行に表示",
    ),
    "list_load_more_fail": MessageLookupByLibrary.simpleMessage(
      "ロードに失敗、タップして再ロード",
    ),
    "list_mode": MessageLookupByLibrary.simpleMessage("リストモード"),
    "listmode_grid": MessageLookupByLibrary.simpleMessage("グリッド"),
    "listmode_grid_tags": MessageLookupByLibrary.simpleMessage("グリッド - タグ"),
    "listmode_medium": MessageLookupByLibrary.simpleMessage("リスト（中）"),
    "listmode_small": MessageLookupByLibrary.simpleMessage("リスト（小）"),
    "listmode_waterfall": MessageLookupByLibrary.simpleMessage("滝"),
    "listmode_waterfall_large": MessageLookupByLibrary.simpleMessage("滝（大）"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中…"),
    "local_favorite": MessageLookupByLibrary.simpleMessage("ローカル"),
    "login": MessageLookupByLibrary.simpleMessage("ログイン"),
    "login_web": MessageLookupByLibrary.simpleMessage("Webでログイン"),
    "max_history": MessageLookupByLibrary.simpleMessage("最大履歴"),
    "min": MessageLookupByLibrary.simpleMessage("分"),
    "model": m68,
    "more_actions": MessageLookupByLibrary.simpleMessage("その他"),
    "more_thumbnails": MessageLookupByLibrary.simpleMessage("他のサムネイル"),
    "multi_download": MessageLookupByLibrary.simpleMessage("マルチダウンロード"),
    "mytags_on_website": MessageLookupByLibrary.simpleMessage("タグの管理"),
    "native_http_client_adapter": MessageLookupByLibrary.simpleMessage(
      "Native HTTP Client Adapter",
    ),
    "never": MessageLookupByLibrary.simpleMessage("Never"),
    "newGroup": MessageLookupByLibrary.simpleMessage("作成"),
    "newText": MessageLookupByLibrary.simpleMessage("キーワード"),
    "new_comment": MessageLookupByLibrary.simpleMessage("コメント入力"),
    "no": MessageLookupByLibrary.simpleMessage("しない"),
    "no_limit": MessageLookupByLibrary.simpleMessage("無制限"),
    "no_more_thumbnails": MessageLookupByLibrary.simpleMessage(
      "これ以上サムネイルはありません",
    ),
    "notFav": MessageLookupByLibrary.simpleMessage("お気に入りではない"),
    "not_login": MessageLookupByLibrary.simpleMessage("ログインしない"),
    "off": MessageLookupByLibrary.simpleMessage("オフ"),
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "on": MessageLookupByLibrary.simpleMessage("オン"),
    "one_step_favorite": MessageLookupByLibrary.simpleMessage(
      "One Step Favorite",
    ),
    "one_step_favorite_desc": MessageLookupByLibrary.simpleMessage(
      "Quickly add gallery to favorite, short press to save to the last selected favorite, long press to display the favorite dialog.",
    ),
    "open_supported_links": MessageLookupByLibrary.simpleMessage(
      "Open supported links",
    ),
    "open_supported_links_summary": MessageLookupByLibrary.simpleMessage(
      "Starting with Android 12, apps can only be used as web link handling apps if they are approved. Otherwise it will be processed using the default browser. You can manually approve it here",
    ),
    "open_with_other_apps": MessageLookupByLibrary.simpleMessage("他のアプリで開く"),
    "orientation_auto": MessageLookupByLibrary.simpleMessage("自動回転"),
    "orientation_landscapeLeft": MessageLookupByLibrary.simpleMessage("横向き「左」"),
    "orientation_landscapeRight": MessageLookupByLibrary.simpleMessage(
      "横向き「右」",
    ),
    "orientation_portraitUp": MessageLookupByLibrary.simpleMessage("縦向き"),
    "orientation_system": MessageLookupByLibrary.simpleMessage("既定"),
    "original_image": MessageLookupByLibrary.simpleMessage("オリジナル"),
    "outer_display": MessageLookupByLibrary.simpleMessage("外側ディスプレイ"),
    "p_Archiver": MessageLookupByLibrary.simpleMessage("圧縮パッケージ"),
    "p_Download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "p_Rate": MessageLookupByLibrary.simpleMessage("評価"),
    "p_Similar": MessageLookupByLibrary.simpleMessage("類似のギャラリー"),
    "p_Torrent": MessageLookupByLibrary.simpleMessage("トレント"),
    "page_count": m69,
    "page_range": MessageLookupByLibrary.simpleMessage("ページ範囲"),
    "page_range_error": MessageLookupByLibrary.simpleMessage("入力範囲エラー"),
    "page_view_type": MessageLookupByLibrary.simpleMessage("Page View Type"),
    "passwd": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paused": MessageLookupByLibrary.simpleMessage("一時停止"),
    "phash_block_list": MessageLookupByLibrary.simpleMessage("ブロックリスト"),
    "phash_check": MessageLookupByLibrary.simpleMessage(
      "知覚的ハッシュチェック（類似画像のブロック）",
    ),
    "pls_i_passwd": MessageLookupByLibrary.simpleMessage("パスワードを入力してください"),
    "pls_i_username": MessageLookupByLibrary.simpleMessage("ユーザー名を入力してください"),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portrait": MessageLookupByLibrary.simpleMessage("縦向き"),
    "preload_image": MessageLookupByLibrary.simpleMessage("プリロード"),
    "processing": MessageLookupByLibrary.simpleMessage("ロード中"),
    "proxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "proxy_type": MessageLookupByLibrary.simpleMessage("Proxy Type"),
    "pure_black": MessageLookupByLibrary.simpleMessage("真っ黒"),
    "quick_search": MessageLookupByLibrary.simpleMessage("クイック検索"),
    "ranking_period": MessageLookupByLibrary.simpleMessage("ランキング期間"),
    "read": MessageLookupByLibrary.simpleMessage("閲覧"),
    "read_from_clipboard": MessageLookupByLibrary.simpleMessage(
      "クリップボードから読み込む",
    ),
    "read_setting": MessageLookupByLibrary.simpleMessage("閲覧設定"),
    "read_view_compatible_mode": MessageLookupByLibrary.simpleMessage("適合モード"),
    "reader_auto_read": MessageLookupByLibrary.simpleMessage("自動ページめくり"),
    "reader_auto_read_interval": MessageLookupByLibrary.simpleMessage("めくり間隔"),
    "reader_custom_interval": MessageLookupByLibrary.simpleMessage("カスタム…"),
    "reader_double_even_left": MessageLookupByLibrary.simpleMessage(
      "見開き（偶数ページ左）",
    ),
    "reader_double_odd_left": MessageLookupByLibrary.simpleMessage(
      "見開き（奇数ページ左）",
    ),
    "reader_double_page": MessageLookupByLibrary.simpleMessage("見開き"),
    "reader_fill_footer": MessageLookupByLibrary.simpleMessage(
      "その向きで閲覧中はステータスバーなどを隠し、画像をセーフエリアを無視して画面いっぱいに表示します",
    ),
    "reader_fill_landscape": MessageLookupByLibrary.simpleMessage("横向きで全画面表示"),
    "reader_fill_portrait": MessageLookupByLibrary.simpleMessage("縦向きで全画面表示"),
    "reader_interval_seconds": m70,
    "reader_next_page": MessageLookupByLibrary.simpleMessage("次のページ"),
    "reader_page_layout": MessageLookupByLibrary.simpleMessage("ページレイアウト"),
    "reader_page_of": m71,
    "reader_previous_page": MessageLookupByLibrary.simpleMessage("前のページ"),
    "reader_single_page": MessageLookupByLibrary.simpleMessage("単ページ"),
    "reader_surface_standard": MessageLookupByLibrary.simpleMessage("標準"),
    "reader_surface_tabletop": MessageLookupByLibrary.simpleMessage("テーブルトップ"),
    "reader_turn_page": MessageLookupByLibrary.simpleMessage("ページ送り"),
    "reader_vertical": MessageLookupByLibrary.simpleMessage("縦スクロール"),
    "reading_direction": MessageLookupByLibrary.simpleMessage("読み方"),
    "rebuild_tasks_data": MessageLookupByLibrary.simpleMessage(
      "Rebuild tasks data",
    ),
    "redirect_thumb_link": MessageLookupByLibrary.simpleMessage(
      "Redirect Thumb Link",
    ),
    "redirect_thumb_link_summary": MessageLookupByLibrary.simpleMessage(
      "Redirect Thumb Link To ehgt.org",
    ),
    "redownload": MessageLookupByLibrary.simpleMessage("再ダウンロード"),
    "refresh_igneous": MessageLookupByLibrary.simpleMessage("Refresh Igneous"),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "regex_format_error": MessageLookupByLibrary.simpleMessage(
      "Regexフォーマットエラー",
    ),
    "reload": MessageLookupByLibrary.simpleMessage("再読み込み"),
    "reload_image": MessageLookupByLibrary.simpleMessage("再ロード"),
    "remove_all": MessageLookupByLibrary.simpleMessage("すべて削除"),
    "remove_from_favorites": MessageLookupByLibrary.simpleMessage("お気に入りから削除"),
    "reply_to_comment": MessageLookupByLibrary.simpleMessage("返信"),
    "resample_image": MessageLookupByLibrary.simpleMessage("サンプル"),
    "reset_cost": MessageLookupByLibrary.simpleMessage("リセットコスト"),
    "restore_tasks_data": MessageLookupByLibrary.simpleMessage(
      "Restore tasks data",
    ),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "right_to_left": MessageLookupByLibrary.simpleMessage("右から左"),
    "s_Advanced_Options": MessageLookupByLibrary.simpleMessage("オプション"),
    "s_Between": MessageLookupByLibrary.simpleMessage(""),
    "s_Disable_default_filters": MessageLookupByLibrary.simpleMessage(
      "デフォルトフィルターの無効化",
    ),
    "s_Minimum_Rating": MessageLookupByLibrary.simpleMessage("評価の下限"),
    "s_Only_Show_Galleries_With_Torrents": MessageLookupByLibrary.simpleMessage(
      "Torrentがあるのみ",
    ),
    "s_Search_Downvoted_Tags": MessageLookupByLibrary.simpleMessage("低評価タグ"),
    "s_Search_Fav_Name": MessageLookupByLibrary.simpleMessage("Search Name"),
    "s_Search_Fav_Note": MessageLookupByLibrary.simpleMessage("Search Note"),
    "s_Search_Fav_Tags": MessageLookupByLibrary.simpleMessage("Search Tags"),
    "s_Search_Gallery_Description": MessageLookupByLibrary.simpleMessage("詳細"),
    "s_Search_Gallery_Name": MessageLookupByLibrary.simpleMessage("ギャラリー名"),
    "s_Search_Gallery_Tags": MessageLookupByLibrary.simpleMessage("タグ"),
    "s_Search_Low_Power_Tags": MessageLookupByLibrary.simpleMessage("弱いタグ"),
    "s_Search_Torrent_Filenames": MessageLookupByLibrary.simpleMessage(
      "トレントファイル名",
    ),
    "s_Show_Expunged_Galleries": MessageLookupByLibrary.simpleMessage("削除済み"),
    "s_and": MessageLookupByLibrary.simpleMessage("〜"),
    "s_pages": MessageLookupByLibrary.simpleMessage("ページ"),
    "s_stars": m72,
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "save_current_image": MessageLookupByLibrary.simpleMessage("表示中の画像を保存"),
    "save_into_album": MessageLookupByLibrary.simpleMessage("保存"),
    "save_original_image": MessageLookupByLibrary.simpleMessage("元の画像を保存"),
    "saved_successfully": MessageLookupByLibrary.simpleMessage("保存しました"),
    "screen_orientation": MessageLookupByLibrary.simpleMessage("回転モード"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "searchTexts": MessageLookupByLibrary.simpleMessage("検索"),
    "search_by_image": MessageLookupByLibrary.simpleMessage("画像で検索"),
    "search_history": MessageLookupByLibrary.simpleMessage("検索履歴"),
    "search_title": MessageLookupByLibrary.simpleMessage("タイトルで検索"),
    "search_type": MessageLookupByLibrary.simpleMessage("検索タイプ"),
    "second": MessageLookupByLibrary.simpleMessage("秒"),
    "security": MessageLookupByLibrary.simpleMessage("セキュリティ"),
    "security_blurredInRecentTasks": MessageLookupByLibrary.simpleMessage(
      "システムタスクに非表示",
    ),
    "see_all": MessageLookupByLibrary.simpleMessage("すべて"),
    "setting_group_browse": MessageLookupByLibrary.simpleMessage("閲覧"),
    "setting_group_content": MessageLookupByLibrary.simpleMessage("コンテンツ"),
    "setting_group_system": MessageLookupByLibrary.simpleMessage("システム"),
    "setting_on_website": MessageLookupByLibrary.simpleMessage("ウエブサイトで設定"),
    "setting_site": MessageLookupByLibrary.simpleMessage("サイト"),
    "share": MessageLookupByLibrary.simpleMessage("共有"),
    "share_image": MessageLookupByLibrary.simpleMessage("共有"),
    "show_comment_avatar": MessageLookupByLibrary.simpleMessage("アバターを表示"),
    "show_comments": MessageLookupByLibrary.simpleMessage("コメント"),
    "show_english_title": MessageLookupByLibrary.simpleMessage("英語タイトルを表示"),
    "show_filter": MessageLookupByLibrary.simpleMessage("フィルターを表示"),
    "show_gallery_tags": MessageLookupByLibrary.simpleMessage("ダグ"),
    "show_japanese_title": MessageLookupByLibrary.simpleMessage("日本語タイトルを表示"),
    "show_jpn_title": MessageLookupByLibrary.simpleMessage("日本語タイトルを表示"),
    "show_only_uploader_comment": MessageLookupByLibrary.simpleMessage(
      "アップローダのコメントのみ",
    ),
    "show_page_interval": MessageLookupByLibrary.simpleMessage("間紙"),
    "sidebar_library": MessageLookupByLibrary.simpleMessage("ライブラリ"),
    "skip": MessageLookupByLibrary.simpleMessage("スキップ"),
    "slide_out_page": MessageLookupByLibrary.simpleMessage("Slide Out Page"),
    "sni_add_custom_doh": MessageLookupByLibrary.simpleMessage(
      "カスタム DoH サーバーを追加",
    ),
    "sni_add_custom_doh_bootstrap": MessageLookupByLibrary.simpleMessage(
      "ブートストラップ IP（任意、カンマ区切り）",
    ),
    "sni_add_custom_doh_name": MessageLookupByLibrary.simpleMessage("名前（任意）"),
    "sni_add_custom_doh_url": MessageLookupByLibrary.simpleMessage(
      "DoH URL（https://...）",
    ),
    "sni_bypass": MessageLookupByLibrary.simpleMessage("ダイレクト接続"),
    "sni_conflict_desc": MessageLookupByLibrary.simpleMessage(
      "通信が Surge / VPN 経由の可能性があります。併用すると接続に失敗する場合があります。",
    ),
    "sni_conflict_title": MessageLookupByLibrary.simpleMessage(
      "システムプロキシまたは Fake-IP を検出",
    ),
    "sni_custom_hosts_footer": MessageLookupByLibrary.simpleMessage(
      "手動同期で毎日検証された DoH リストと予備 IP をリポジトリから取得します。",
    ),
    "sni_diag_eh_nodes": MessageLookupByLibrary.simpleMessage("E-Hentai ノード確認"),
    "sni_diag_retest": MessageLookupByLibrary.simpleMessage("再テスト"),
    "sni_diag_section": MessageLookupByLibrary.simpleMessage("接続診断"),
    "sni_diag_summary_ok": m73,
    "sni_diag_tap_to_test": MessageLookupByLibrary.simpleMessage("タップして確認"),
    "sni_doh_auto": MessageLookupByLibrary.simpleMessage("自動選択"),
    "sni_doh_auto_selected": m74,
    "sni_doh_polluted": MessageLookupByLibrary.simpleMessage("汚染の疑い"),
    "sni_doh_section": MessageLookupByLibrary.simpleMessage("DoH サーバー"),
    "sni_doh_speed_test": MessageLookupByLibrary.simpleMessage("速度計測"),
    "sni_doh_sync": MessageLookupByLibrary.simpleMessage("同期"),
    "sni_doh_sync_failed": MessageLookupByLibrary.simpleMessage(
      "同期に失敗しました（ローカル一覧を使用）",
    ),
    "sni_doh_sync_success": MessageLookupByLibrary.simpleMessage(
      "最新の DoH リストを同期しました",
    ),
    "sni_doh_synced_at": m75,
    "sni_doh_syncing": MessageLookupByLibrary.simpleMessage("同期中…"),
    "sni_doh_testing": MessageLookupByLibrary.simpleMessage("計測中…"),
    "sni_mode_compat": MessageLookupByLibrary.simpleMessage("互換モード"),
    "sni_mode_compat_desc": MessageLookupByLibrary.simpleMessage(
      "DoH 解決と TCP パケット分割送信（旧ネットワーク互換・完全な証明書検証）",
    ),
    "sni_mode_enhanced": MessageLookupByLibrary.simpleMessage("拡張ダイレクト（推奨）"),
    "sni_mode_enhanced_desc": MessageLookupByLibrary.simpleMessage(
      "DoH 解決と TLS ClientHello 分割送信（完全な証明書検証を維持）",
    ),
    "sni_mode_enhanced_short": MessageLookupByLibrary.simpleMessage("拡張ダイレクト"),
    "sni_mode_section": MessageLookupByLibrary.simpleMessage("接続モード"),
    "sni_mode_standard": MessageLookupByLibrary.simpleMessage("標準接続"),
    "sni_mode_standard_desc": MessageLookupByLibrary.simpleMessage(
      "システムまたはプロキシ設定を使用（Surge / VPN 推奨）",
    ),
    "sni_status_failed": MessageLookupByLibrary.simpleMessage("失敗"),
    "sni_status_timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "sni_status_untested": MessageLookupByLibrary.simpleMessage("未計測"),
    "sni_switch_to_standard": MessageLookupByLibrary.simpleMessage("標準接続に戻す"),
    "sp_add_quick_search": MessageLookupByLibrary.simpleMessage("クイック検索に追加"),
    "sp_add_tag": m76,
    "sp_all": MessageLookupByLibrary.simpleMessage("すべて"),
    "sp_all_favcats": MessageLookupByLibrary.simpleMessage("すべてのお気に入り"),
    "sp_archive_original": MessageLookupByLibrary.simpleMessage("オリジナルアーカイブ"),
    "sp_archive_resample": MessageLookupByLibrary.simpleMessage("リサンプルアーカイブ"),
    "sp_archiver_error": MessageLookupByLibrary.simpleMessage("読み込みに失敗しました"),
    "sp_archiver_hath": MessageLookupByLibrary.simpleMessage("H@H リモートダウンロード"),
    "sp_archiver_loading": MessageLookupByLibrary.simpleMessage(
      "アーカイブ情報を読み込み中",
    ),
    "sp_archiver_local": MessageLookupByLibrary.simpleMessage("端末にダウンロード"),
    "sp_category": MessageLookupByLibrary.simpleMessage("カテゴリ"),
    "sp_change_image": MessageLookupByLibrary.simpleMessage("変更"),
    "sp_clear": MessageLookupByLibrary.simpleMessage("クリア"),
    "sp_clear_text": MessageLookupByLibrary.simpleMessage("テキストを消去"),
    "sp_date": MessageLookupByLibrary.simpleMessage("日付"),
    "sp_done": MessageLookupByLibrary.simpleMessage("完了"),
    "sp_favcat": MessageLookupByLibrary.simpleMessage("お気に入り"),
    "sp_filter": MessageLookupByLibrary.simpleMessage("フィルター"),
    "sp_first_page": MessageLookupByLibrary.simpleMessage("最初"),
    "sp_free": MessageLookupByLibrary.simpleMessage("無料"),
    "sp_go": MessageLookupByLibrary.simpleMessage("移動"),
    "sp_hide_keyboard": MessageLookupByLibrary.simpleMessage("キーボードを閉じる"),
    "sp_image_search": MessageLookupByLibrary.simpleMessage("画像で検索"),
    "sp_image_search_options": MessageLookupByLibrary.simpleMessage("検索オプション"),
    "sp_include_expunged": MessageLookupByLibrary.simpleMessage("削除済みを含む"),
    "sp_invert_selection": MessageLookupByLibrary.simpleMessage("反転"),
    "sp_last_page": MessageLookupByLibrary.simpleMessage("最後"),
    "sp_middle_page": MessageLookupByLibrary.simpleMessage("中間"),
    "sp_more": MessageLookupByLibrary.simpleMessage("その他"),
    "sp_only_covers": MessageLookupByLibrary.simpleMessage("表紙のみ"),
    "sp_open_link": MessageLookupByLibrary.simpleMessage("ギャラリーリンクを開く"),
    "sp_optional": MessageLookupByLibrary.simpleMessage("任意"),
    "sp_original": MessageLookupByLibrary.simpleMessage("オリジナル"),
    "sp_page_first": MessageLookupByLibrary.simpleMessage("最初"),
    "sp_page_last": MessageLookupByLibrary.simpleMessage("最後"),
    "sp_page_next": MessageLookupByLibrary.simpleMessage("次へ"),
    "sp_page_prev": MessageLookupByLibrary.simpleMessage("前へ"),
    "sp_page_total": m77,
    "sp_pick_image": MessageLookupByLibrary.simpleMessage("タップして画像を選択"),
    "sp_quick_search_list": MessageLookupByLibrary.simpleMessage("クイック検索一覧"),
    "sp_rate_submit": MessageLookupByLibrary.simpleMessage("評価を送信"),
    "sp_rating_summary": m78,
    "sp_recent_searches": MessageLookupByLibrary.simpleMessage("最近の検索"),
    "sp_refresh": MessageLookupByLibrary.simpleMessage("更新"),
    "sp_reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "sp_retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "sp_search_for": m79,
    "sp_search_placeholder": MessageLookupByLibrary.simpleMessage(
      "タイトル・タグを検索、またはリンクを貼り付け",
    ),
    "sp_seek_hint": MessageLookupByLibrary.simpleMessage(
      "日付 2024-05-01 · オフセット 3d 2w 1y · または GID",
    ),
    "sp_seek_newer": MessageLookupByLibrary.simpleMessage("新しい方へ"),
    "sp_seek_older": MessageLookupByLibrary.simpleMessage("古い方へ"),
    "sp_seek_section": MessageLookupByLibrary.simpleMessage("日付または GID で移動"),
    "sp_select_all": MessageLookupByLibrary.simpleMessage("すべて"),
    "sp_show_date_picker": MessageLookupByLibrary.simpleMessage("日付を選択"),
    "sp_similar_scan": MessageLookupByLibrary.simpleMessage("類似スキャン"),
    "sp_start_search": MessageLookupByLibrary.simpleMessage("検索"),
    "sp_suggestions": MessageLookupByLibrary.simpleMessage("候補"),
    "sp_tags_added": m80,
    "sp_tags_example": MessageLookupByLibrary.simpleMessage(
      "例: female:glasses, full color",
    ),
    "sp_thumbs_jump": MessageLookupByLibrary.simpleMessage("プレビューページへ"),
    "sp_thumbs_per_page": m81,
    "sp_torrent_completed": MessageLookupByLibrary.simpleMessage("完了"),
    "sp_torrent_download": MessageLookupByLibrary.simpleMessage("トレントをダウンロード"),
    "sp_torrent_empty": MessageLookupByLibrary.simpleMessage("利用できるトレントはありません"),
    "sp_torrent_magnet": MessageLookupByLibrary.simpleMessage("マグネットを共有"),
    "sp_torrent_peers": MessageLookupByLibrary.simpleMessage("ピア"),
    "sp_torrent_seeds": MessageLookupByLibrary.simpleMessage("シード"),
    "sp_torrent_title": m82,
    "sp_translate": MessageLookupByLibrary.simpleMessage("翻訳"),
    "split_follows_divider": MessageLookupByLibrary.simpleMessage("分割・仕切りで変化"),
    "sync_group": MessageLookupByLibrary.simpleMessage("グループ同期"),
    "sync_history": MessageLookupByLibrary.simpleMessage("履歴同期"),
    "sync_quick_search": MessageLookupByLibrary.simpleMessage("クイック検索同期"),
    "sync_read_progress": MessageLookupByLibrary.simpleMessage("進歩同期"),
    "system_proxy": MessageLookupByLibrary.simpleMessage("System Proxy"),
    "system_share": MessageLookupByLibrary.simpleMessage("シェア"),
    "t_Clear_all_history": MessageLookupByLibrary.simpleMessage("削除しますか？"),
    "tab_download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "tab_favorite": MessageLookupByLibrary.simpleMessage("お気に入り"),
    "tab_gallery": MessageLookupByLibrary.simpleMessage("ギャラリー"),
    "tab_history": MessageLookupByLibrary.simpleMessage("閲覧履歴"),
    "tab_history_duo_sidebar_note": MessageLookupByLibrary.simpleMessage(
      "「履歴」タブは iPhone Duo のサイドバーには表示されません。ページ上部のアクションバーから開けます。",
    ),
    "tab_popular": MessageLookupByLibrary.simpleMessage("人気"),
    "tab_setting": MessageLookupByLibrary.simpleMessage("設定"),
    "tab_sort": MessageLookupByLibrary.simpleMessage("長押しで並べ替え"),
    "tab_toplist": MessageLookupByLibrary.simpleMessage("ランキング"),
    "tab_watched": MessageLookupByLibrary.simpleMessage("登録"),
    "tabbar_setting": MessageLookupByLibrary.simpleMessage("カテゴリー設定"),
    "tablet_layout": MessageLookupByLibrary.simpleMessage("タブレットUI"),
    "tagNamespace": m83,
    "tag_add_to_mytag": MessageLookupByLibrary.simpleMessage("マイタグに追加"),
    "tag_dialog_Default_color": MessageLookupByLibrary.simpleMessage(
      "Default Color",
    ),
    "tag_dialog_Hide": MessageLookupByLibrary.simpleMessage("非表示"),
    "tag_dialog_TagColor": MessageLookupByLibrary.simpleMessage("色"),
    "tag_dialog_Watch": MessageLookupByLibrary.simpleMessage("登録"),
    "tag_dialog_tagWeight": MessageLookupByLibrary.simpleMessage("タグの重さ"),
    "tag_limit": MessageLookupByLibrary.simpleMessage("タグ制限"),
    "tag_vote_down": MessageLookupByLibrary.simpleMessage("反対"),
    "tag_vote_up": MessageLookupByLibrary.simpleMessage("いいね！"),
    "tag_withdraw_vote": MessageLookupByLibrary.simpleMessage("いいね！を消す"),
    "tags": MessageLookupByLibrary.simpleMessage("タグ"),
    "tap_to_turn_page_anima": MessageLookupByLibrary.simpleMessage(
      "Tap to turn page animations",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "thumbnails": MessageLookupByLibrary.simpleMessage("サムネイル"),
    "title": MessageLookupByLibrary.simpleMessage("タイトル"),
    "title_showing": MessageLookupByLibrary.simpleMessage("表示中"),
    "tolist_alltime": MessageLookupByLibrary.simpleMessage("史上"),
    "tolist_past_month": MessageLookupByLibrary.simpleMessage("月中"),
    "tolist_past_year": MessageLookupByLibrary.simpleMessage("年中"),
    "tolist_yesterday": MessageLookupByLibrary.simpleMessage("一日中"),
    "top_to_bottom": MessageLookupByLibrary.simpleMessage("上から下へ（連続）"),
    "turn_page_anima": MessageLookupByLibrary.simpleMessage("ページめくりアニメーション"),
    "uc_Chinese": MessageLookupByLibrary.simpleMessage("中国語"),
    "uc_Dutch": MessageLookupByLibrary.simpleMessage("オランダ語"),
    "uc_English": MessageLookupByLibrary.simpleMessage("英語"),
    "uc_French": MessageLookupByLibrary.simpleMessage("フランス語"),
    "uc_German": MessageLookupByLibrary.simpleMessage("ドイツ語"),
    "uc_Hungarian": MessageLookupByLibrary.simpleMessage("ハンガリー語"),
    "uc_Italian": MessageLookupByLibrary.simpleMessage("イタリア語"),
    "uc_Japanese": MessageLookupByLibrary.simpleMessage("日本語"),
    "uc_Korean": MessageLookupByLibrary.simpleMessage("韓国語"),
    "uc_NA": MessageLookupByLibrary.simpleMessage("N/A"),
    "uc_Original": MessageLookupByLibrary.simpleMessage("オリジナル"),
    "uc_Other": MessageLookupByLibrary.simpleMessage("その他"),
    "uc_Polish": MessageLookupByLibrary.simpleMessage("ポーランド語"),
    "uc_Portuguese": MessageLookupByLibrary.simpleMessage("ポルトガル語"),
    "uc_Rewrite": MessageLookupByLibrary.simpleMessage("書き直し"),
    "uc_Russian": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "uc_Spanish": MessageLookupByLibrary.simpleMessage("スペイン語"),
    "uc_Thai": MessageLookupByLibrary.simpleMessage("タイ語"),
    "uc_Translated": MessageLookupByLibrary.simpleMessage("翻訳"),
    "uc_Vietnamese": MessageLookupByLibrary.simpleMessage("ベトナム語"),
    "uc_ar_0": MessageLookupByLibrary.simpleMessage("手動選択、手動開始（デフォルト）"),
    "uc_ar_1": MessageLookupByLibrary.simpleMessage("手動選択、自動開始"),
    "uc_ar_2": MessageLookupByLibrary.simpleMessage("自動選択（オリジナル）、手動開始"),
    "uc_ar_3": MessageLookupByLibrary.simpleMessage("自動選択（オリジナル）、自動開始"),
    "uc_ar_4": MessageLookupByLibrary.simpleMessage("自動選択（サンプル）、手動開始"),
    "uc_ar_5": MessageLookupByLibrary.simpleMessage("自動選択（サンプル）、自動開始"),
    "uc_archiver_desc": MessageLookupByLibrary.simpleMessage(
      "Archiverのデフォルトの動作は、コストとオリジナルまたはサンプルアーカイブの選択を確認し、他の場所でクリックまたはコピーできるリンクを表示します。この動作はここで変更できます。",
    ),
    "uc_archiver_set": MessageLookupByLibrary.simpleMessage("圧縮パッケージ"),
    "uc_artist": MessageLookupByLibrary.simpleMessage("作者"),
    "uc_auto": MessageLookupByLibrary.simpleMessage("自動"),
    "uc_character": MessageLookupByLibrary.simpleMessage("キャラクター"),
    "uc_comments_show_votes": MessageLookupByLibrary.simpleMessage("評価を表示"),
    "uc_comments_sort_order": MessageLookupByLibrary.simpleMessage("並べ替え"),
    "uc_crt_profile": MessageLookupByLibrary.simpleMessage("新しい作る"),
    "uc_cs_0": MessageLookupByLibrary.simpleMessage("最古"),
    "uc_cs_1": MessageLookupByLibrary.simpleMessage("最新"),
    "uc_cs_2": MessageLookupByLibrary.simpleMessage("評価"),
    "uc_del_profile": MessageLookupByLibrary.simpleMessage("プロフィールを削除"),
    "uc_dm_0": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "uc_dm_1": MessageLookupByLibrary.simpleMessage("サムネイル"),
    "uc_dm_2": MessageLookupByLibrary.simpleMessage("詳細付き"),
    "uc_dm_3": MessageLookupByLibrary.simpleMessage("最小化"),
    "uc_dm_4": MessageLookupByLibrary.simpleMessage("最小化+【タグの登録】"),
    "uc_exc_lang": MessageLookupByLibrary.simpleMessage("除外言語"),
    "uc_exc_lang_desc": MessageLookupByLibrary.simpleMessage(
      "ギャラリーリストや検索から特定の言語のギャラリーを非表示にしたい場合は、上記のリストから選択してください。\n検索に関係なく、一致するギャラリーが表示されることはありません。",
    ),
    "uc_exc_up": MessageLookupByLibrary.simpleMessage("除外アップローダ"),
    "uc_exc_up_desc": MessageLookupByLibrary.simpleMessage(
      "特定のアップローダからのギャラリーをリストや検索から非表示にしたい場合は、そのユーザー名を追加してください。1行に1つのユーザー名を入れてください。\nこれらのアップローダからのギャラリーは、検索に関係なく表示されないことに注意してください。",
    ),
    "uc_fav": MessageLookupByLibrary.simpleMessage("お気に入り"),
    "uc_fav_sort": MessageLookupByLibrary.simpleMessage("デフォルト並べ替え方"),
    "uc_fav_sort_desc": MessageLookupByLibrary.simpleMessage(
      "お気に入りページでギャラリーのデフォルトの並べ替え方を選択することもできます。なお、2016年3月のリニューアル以前に追加されたお気に入りにはタイムスタンプが保存されていないため、この設定に関係なくギャラリーの投稿時刻が使用されます。",
    ),
    "uc_female": MessageLookupByLibrary.simpleMessage("女性"),
    "uc_front_page": MessageLookupByLibrary.simpleMessage("トップページ"),
    "uc_front_page_dis_mode": MessageLookupByLibrary.simpleMessage(
      "トップページスタイル",
    ),
    "uc_fs_0": MessageLookupByLibrary.simpleMessage("ギャラリー更新順"),
    "uc_fs_1": MessageLookupByLibrary.simpleMessage("お気に入り日付順"),
    "uc_gallery_comments": MessageLookupByLibrary.simpleMessage("コメント"),
    "uc_group": MessageLookupByLibrary.simpleMessage("サークル"),
    "uc_hath_local_host": MessageLookupByLibrary.simpleMessage("Hentai@Home"),
    "uc_hath_local_host_desc": MessageLookupByLibrary.simpleMessage(
      "この設定は、ローカルネットワーク上でH@Hクライアントがサイトを閲覧するのと同じ公開IPで動作している場合に使用できます。一部のルーターはバグがあり、自身のIPにリクエストをルーティングすることができません。\nブラウズするのと同じPCでクライアントを実行している場合は、ループバックアドレス（127.0.0.1:port）を使用します。クライアントがネットワーク上の別のコンピュータで実行されている場合は、そのローカルネットワークIPを使用します。ブラウザの設定によっては、外部のWebサイトがローカルネットワークIPを持つURLにアクセスできないようになっています。その場合、ホワイトリストに登録しなければならなりません",
    ),
    "uc_img_cussize_desc": MessageLookupByLibrary.simpleMessage(
      "このサイトは、画面幅に合わせて画像を自動的に縮小しますが、画像の最大表示サイズを手動で制限することもできます。自動スケーリングと同様、リサイズはブラウザ側で行われるため、画像のサンプルは行われません。(0 = 制限なし)",
    ),
    "uc_img_horiz": MessageLookupByLibrary.simpleMessage("横向き"),
    "uc_img_load_setting": MessageLookupByLibrary.simpleMessage("画像のロード"),
    "uc_img_size_setting": MessageLookupByLibrary.simpleMessage("画像の規模"),
    "uc_img_vert": MessageLookupByLibrary.simpleMessage("縦向き"),
    "uc_ip_addr_port": MessageLookupByLibrary.simpleMessage("IP Address:Port"),
    "uc_language": MessageLookupByLibrary.simpleMessage("言語"),
    "uc_lt_0": MessageLookupByLibrary.simpleMessage(
      "マウスホバー時【ページのロードが速い、サムネイルが遅れる】",
    ),
    "uc_lt_0_s": MessageLookupByLibrary.simpleMessage("マウスホバー時"),
    "uc_lt_1": MessageLookupByLibrary.simpleMessage(
      "ページのロード時【ページのロードが遅いけど待ち時間なしで表示されます】",
    ),
    "uc_lt_1_s": MessageLookupByLibrary.simpleMessage("ページのロード時"),
    "uc_male": MessageLookupByLibrary.simpleMessage("男性"),
    "uc_mose_over_thumb": MessageLookupByLibrary.simpleMessage("サムネイルの読み込み時"),
    "uc_mpv": MessageLookupByLibrary.simpleMessage("Multi-Page Viewer"),
    "uc_mpv_always": MessageLookupByLibrary.simpleMessage("常に使用"),
    "uc_mpv_stype": MessageLookupByLibrary.simpleMessage("表示スタイル"),
    "uc_mpv_thumb_pane": MessageLookupByLibrary.simpleMessage("サムネイル揃え"),
    "uc_ms_0": MessageLookupByLibrary.simpleMessage("左詰め\n【ブラウザの幅より大きい場合】"),
    "uc_ms_1": MessageLookupByLibrary.simpleMessage("中央揃え\n【ブラウザの幅より大きい場合】"),
    "uc_ms_2": MessageLookupByLibrary.simpleMessage("中央揃え\n【ブラウザの幅と合わせる】"),
    "uc_mt_0": MessageLookupByLibrary.simpleMessage("表示"),
    "uc_mt_1": MessageLookupByLibrary.simpleMessage("非表示"),
    "uc_name_display": MessageLookupByLibrary.simpleMessage("ギャラリー名"),
    "uc_name_display_desc": MessageLookupByLibrary.simpleMessage(
      "多くのギャラリーは英語/ローマ字のタイトルと日本語のタイトルの両方を持っています。どちらのギャラリー名をデフォルトにしますか？",
    ),
    "uc_oi_0": MessageLookupByLibrary.simpleMessage("サンプルを優先"),
    "uc_oi_1": MessageLookupByLibrary.simpleMessage("オリジナルを優先"),
    "uc_ori_image": MessageLookupByLibrary.simpleMessage("オリジナル画像"),
    "uc_ori_image_desc": MessageLookupByLibrary.simpleMessage(
      "オリジナル画像を使用しますか？上記の【自動】とは異なる水平解像度を選択し、問題の画像の幅が広い場合、または元の画像が10MB（1年以上前のライブラリは4MB）より大きい場合、サンプルされた画像が使用されます。",
    ),
    "uc_parody": MessageLookupByLibrary.simpleMessage("パロディー"),
    "uc_pixels": MessageLookupByLibrary.simpleMessage("pixels"),
    "uc_pn_0": MessageLookupByLibrary.simpleMessage("None"),
    "uc_pn_1": MessageLookupByLibrary.simpleMessage("Page Number Only"),
    "uc_pn_2": MessageLookupByLibrary.simpleMessage("Page Number + Name"),
    "uc_profile": MessageLookupByLibrary.simpleMessage("プロフィール"),
    "uc_qb_0": MessageLookupByLibrary.simpleMessage("いいえ"),
    "uc_qb_1": MessageLookupByLibrary.simpleMessage("はい"),
    "uc_rating": MessageLookupByLibrary.simpleMessage("評価付け色"),
    "uc_rating_desc": MessageLookupByLibrary.simpleMessage(
      "デフォルトでは、あなたが評価したギャラリーは、2つ星以下は赤、2.5〜4つ星は緑、4.5または5つ星は青で表示されます。以下にご希望の色の組み合わせを入力してカスタマイズすることができます。\n各文字は星1つを表します。デフォルトのRRGGBは、1つ目と2つ目の星をR(赤)、3つ目と4つ目をG(緑)、5つ目をB(青)で表しています。通常の星には黄色(Y)も使うこともできます。R/G/B/Yの5文字のコンボなら何でも使えます。",
    ),
    "uc_reclass": MessageLookupByLibrary.simpleMessage("クラス替え"),
    "uc_rename": MessageLookupByLibrary.simpleMessage("名前を変更"),
    "uc_res_res": MessageLookupByLibrary.simpleMessage("解像度"),
    "uc_res_res_desc": MessageLookupByLibrary.simpleMessage(
      "画像は通常、オンライン表示用に水平解像度1280pxにサンプルされます。上記の代替解像度のいずれかを選択できます。",
    ),
    "uc_sc_0": MessageLookupByLibrary.simpleMessage("クリック"),
    "uc_sc_1": MessageLookupByLibrary.simpleMessage("常時"),
    "uc_search_r_count": MessageLookupByLibrary.simpleMessage("検索結果数"),
    "uc_search_r_count_desc": MessageLookupByLibrary.simpleMessage(
      "インデックス/検索ページとトレント検索ページの1ページあたりの検索結果数を入力してください。(Hath Perk: ページング拡大が必要)",
    ),
    "uc_selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "uc_set_as_def": MessageLookupByLibrary.simpleMessage("既定に設定"),
    "uc_show_page_num": MessageLookupByLibrary.simpleMessage(
      "Thumbnail Labeling",
    ),
    "uc_tag": MessageLookupByLibrary.simpleMessage("ギャラリータグ"),
    "uc_tag_ft": MessageLookupByLibrary.simpleMessage("タグフィルタリングしきい値"),
    "uc_tag_ft_desc": MessageLookupByLibrary.simpleMessage(
      "マイナスウェイトでマイタグに追加することで、タグをソフトフィルターすることができます。ギャラリーがこの値以上のウェイトを追加するタグを持っている場合、それはビューからフィルタされます。このしきい値は0から-9999の間で設定できます。",
    ),
    "uc_tag_namesp": MessageLookupByLibrary.simpleMessage("タグの名前空間"),
    "uc_tag_short_order": MessageLookupByLibrary.simpleMessage("タグ並べ替え"),
    "uc_tag_wt": MessageLookupByLibrary.simpleMessage("登録タッグしきい値"),
    "uc_tag_wt_desc": MessageLookupByLibrary.simpleMessage(
      "最近アップロードされたギャラリーは、正のウェイトを持つウォッチされたタグが少なくとも1つあり、その登録タグのウェイトの合計がこの値以上であれば、登録ページに含まれます。このしきい値は0から9999の間で設定できます。",
    ),
    "uc_tb_0": MessageLookupByLibrary.simpleMessage("アルファベット順"),
    "uc_tb_1": MessageLookupByLibrary.simpleMessage("パワー順"),
    "uc_thor_hath": MessageLookupByLibrary.simpleMessage("H@H"),
    "uc_thumb_row": MessageLookupByLibrary.simpleMessage("列"),
    "uc_thumb_scaling": MessageLookupByLibrary.simpleMessage("サムネイルズーム"),
    "uc_thumb_scaling_desc": MessageLookupByLibrary.simpleMessage(
      "拡大モードとリストモードのサムネイルは75%から150%の間のカスタム値に拡大縮小できます。",
    ),
    "uc_thumb_setting": MessageLookupByLibrary.simpleMessage("サムネイル設定"),
    "uc_thumb_size": MessageLookupByLibrary.simpleMessage("大きさ"),
    "uc_tl_0": MessageLookupByLibrary.simpleMessage("デフォルトタイトル"),
    "uc_tl_1": MessageLookupByLibrary.simpleMessage("日本語タイトル（可能であれば）"),
    "uc_ts_0": MessageLookupByLibrary.simpleMessage("Auto"),
    "uc_ts_1": MessageLookupByLibrary.simpleMessage("Normal"),
    "uc_ts_2": MessageLookupByLibrary.simpleMessage("Small "),
    "uc_uh_0": MessageLookupByLibrary.simpleMessage("すべてのクライアント（おすすめ）"),
    "uc_uh_0_s": MessageLookupByLibrary.simpleMessage("すべてのクライアント"),
    "uc_uh_1": MessageLookupByLibrary.simpleMessage(
      "Default port clients only (Can be slower. Enable if behind firewall/proxy that blocks outgoing non-standard ports.)",
    ),
    "uc_uh_1_s": MessageLookupByLibrary.simpleMessage(
      "Default port clients only",
    ),
    "uc_uh_2": MessageLookupByLibrary.simpleMessage(
      "No [Modern/HTTPS] (Donator only. You will not be able to browse as many pages. Recommended only if having severe problems.)",
    ),
    "uc_uh_2_s": MessageLookupByLibrary.simpleMessage("No [Modern/HTTPS]"),
    "uc_uh_3": MessageLookupByLibrary.simpleMessage(
      "No [Legacy/HTTP] (Donator only. May not work by default in modern browsers. Recommended for legacy/outdated browsers only.)",
    ),
    "uc_uh_3_s": MessageLookupByLibrary.simpleMessage("No [Legacy/HTTP]"),
    "uc_viewport_or": MessageLookupByLibrary.simpleMessage("Viewportオーバーライド"),
    "uc_viewport_or_desc": MessageLookupByLibrary.simpleMessage(
      "デフォルトではDPIに基づいて自動的に計算され、サムネイルの100%スケールでは640から1400の間で妥当な値が設定されます。",
    ),
    "uc_xt_desc": MessageLookupByLibrary.simpleMessage(
      "特定の名前空間をデフォルトのタグ検索から除外したい場合は、上記でチェックできます。これは、これらの名前空間に含まれるタグを持つギャラリーが表示されないようにするのではなく、タグを検索するときに、これらの名前空間を見送るようにするだけであることに注意してください。",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unlimited": MessageLookupByLibrary.simpleMessage("無制限"),
    "update_to_version": m84,
    "upload_avatar": MessageLookupByLibrary.simpleMessage("アバターをアップロード"),
    "uploader": MessageLookupByLibrary.simpleMessage("アップローダー"),
    "user_login": MessageLookupByLibrary.simpleMessage("ユーザーログイン"),
    "user_name": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "version": MessageLookupByLibrary.simpleMessage("バージョン"),
    "vibrate_feedback": MessageLookupByLibrary.simpleMessage("バイブレーション"),
    "volume_key_turn_page": MessageLookupByLibrary.simpleMessage(
      "ボリュームキーナビゲーション",
    ),
    "vote_down_successfully": MessageLookupByLibrary.simpleMessage("反対しました"),
    "vote_successfully": MessageLookupByLibrary.simpleMessage("評価しました"),
    "vote_up_successfully": MessageLookupByLibrary.simpleMessage("いいね！しました"),
    "webdav_Account": MessageLookupByLibrary.simpleMessage("WebDAVアカウント"),
    "webdav_max_connections": MessageLookupByLibrary.simpleMessage(
      "WebDAV Max Connections",
    ),
    "welcome_text": MessageLookupByLibrary.simpleMessage("いらっしゃいませ！"),
  };
}
