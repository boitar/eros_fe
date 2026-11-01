// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ko_KR locale. All the
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
  String get localeName => 'ko_KR';

  static String m0(site) => "현재 ${site}";

  static String m1(modelName) => "Model ${modelName}";

  static String m2(rating) => "${rating} ⭐";

  static String m3(tagNamespace) => "${Intl.select(tagNamespace, {
            'reclass': 'reclass',
            'language': 'language',
            'parody': 'parody',
            'character': 'character',
            'group': 'group',
            'artist': 'artist',
            'male': 'male',
            'female': 'female',
            'mixed': 'mixed',
            'cosplayer': 'cosplayer',
            'other': 'other',
            'temp': 'temp',
          })}";

  static String m4(version) => "Update to ${version}";

  static String m5(seconds) => "${seconds}초";

  static String m6(page) => "이어 읽기 · ${page}페이지";

  static String m7(count) => "${count}페이지";

  static String m8(count) => "댓글 ${count}개";

  static String m9(count) => "${count}열";

  static String m10(min, max) => "${min}–${max}열";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "upload_avatar": MessageLookupByLibrary.simpleMessage("아바타 업로드"),
        "avatar_source": MessageLookupByLibrary.simpleMessage("이미지 소스 선택"),
        "avatar_from_album": MessageLookupByLibrary.simpleMessage("사진 보관함"),
        "avatar_from_file": MessageLookupByLibrary.simpleMessage("파일"),
        "avatar_from_url": MessageLookupByLibrary.simpleMessage("이미지 URL"),
        "avatar_target": MessageLookupByLibrary.simpleMessage("아바타 사용 위치 선택"),
        "avatar_use_forum": MessageLookupByLibrary.simpleMessage("EH 포럼에 업로드"),
        "avatar_use_local": MessageLookupByLibrary.simpleMessage("이 기기에서만 사용"),
        "avatar_upload_success": MessageLookupByLibrary.simpleMessage("아바타가 업로드되었습니다"),
        "avatar_local_success": MessageLookupByLibrary.simpleMessage("아바타가 업데이트되었습니다"),
        "avatar_cf_verify_title": MessageLookupByLibrary.simpleMessage("Cloudflare 인증 필요"),
        "avatar_cf_verify_message": MessageLookupByLibrary.simpleMessage("포럼이 Cloudflare로 보호되어 있습니다. 내장 브라우저에서 인증을 완료하면 업로드가 자동으로 재시도됩니다."),
        "liquid_glass_top_layout": MessageLookupByLibrary.simpleMessage("상단 카테고리 배치"),
        "liquid_glass_two_row": MessageLookupByLibrary.simpleMessage("두 줄 (기본값)"),
        "liquid_glass_two_row_detail": MessageLookupByLibrary.simpleMessage("작업과 카테고리를 별도 줄에 표시"),
        "liquid_glass_inline": MessageLookupByLibrary.simpleMessage("간결한 한 줄"),
        "liquid_glass_inline_detail": MessageLookupByLibrary.simpleMessage("작업과 카테고리를 한 줄에 표시"),
        "favorite_note_hint": MessageLookupByLibrary.simpleMessage("메모 (선택 사항)"),
        "KEEP_IT_SAFE": MessageLookupByLibrary.simpleMessage("안전하게 보관하세요!"),
        "QR_code_block": MessageLookupByLibrary.simpleMessage(
            "Block images containing QR codes"),
    "image_save_busy": MessageLookupByLibrary.simpleMessage("이미지를 저장하고 있습니다."),
    "image_save_download": MessageLookupByLibrary.simpleMessage(
      "이미지를 다운로드하지 못했습니다. 다시 시도해 주세요.",
    ),
    "image_save_invalid": MessageLookupByLibrary.simpleMessage(
      "이미지 파일이 없거나 불완전하거나 유효하지 않습니다.",
    ),
    "image_save_permission": MessageLookupByLibrary.simpleMessage(
      "사진 추가 권한이 없습니다. 시스템 설정에서 허용해 주세요. LiveContainer를 사용하는 경우 해당 앱의 사진 권한을 확인해 주세요.",
    ),
    "image_save_unsupported": MessageLookupByLibrary.simpleMessage(
      "사진 보관함에서 지원하지 않는 이미지 형식입니다.",
    ),
    "image_save_write": MessageLookupByLibrary.simpleMessage(
      "사진 보관함에 저장하지 못했습니다. 다시 시도해 주세요.",
    ),
    "save_current_image": MessageLookupByLibrary.simpleMessage("현재 이미지 저장"),
    "save_original_image": MessageLookupByLibrary.simpleMessage("원본 이미지 저장"),
        "about": MessageLookupByLibrary.simpleMessage("정보"),
        "add_quick_search": MessageLookupByLibrary.simpleMessage("빠른 검색 추가"),
        "add_tag_placeholder":
            MessageLookupByLibrary.simpleMessage("새로운 태그를 입력해주세요, 쉼표로 구분됩니다."),
        "add_tags": MessageLookupByLibrary.simpleMessage("태그 추가"),
        "add_to_favorites": MessageLookupByLibrary.simpleMessage("즐겨찾기에 추가"),
        "add_to_phash_block_list": MessageLookupByLibrary.simpleMessage(
            "Add to Perceptual Hash Block List"),
        "advanced": MessageLookupByLibrary.simpleMessage("고급"),
        "aggregate": MessageLookupByLibrary.simpleMessage("Aggregate"),
        "aggregate_groups":
            MessageLookupByLibrary.simpleMessage("Aggregate groups"),
        "all_Favorites": MessageLookupByLibrary.simpleMessage("전체 즐겨찾기"),
        "all_comment": MessageLookupByLibrary.simpleMessage("모든 댓글"),
        "all_thumbnails": MessageLookupByLibrary.simpleMessage("모든 미리 보기"),
        "allow_media_scan": MessageLookupByLibrary.simpleMessage("미디어 스캔 허용"),
        "always": MessageLookupByLibrary.simpleMessage("Always"),
        "app_title": MessageLookupByLibrary.simpleMessage("Eros-FE"),
        "ask_me": MessageLookupByLibrary.simpleMessage("Ask for me"),
        "auth_biometricHint":
            MessageLookupByLibrary.simpleMessage("Verify identity"),
        "auth_signInTitle":
            MessageLookupByLibrary.simpleMessage("Authentication required"),
        "author": MessageLookupByLibrary.simpleMessage("Author"),
        "autoLock": MessageLookupByLibrary.simpleMessage("자동 잠금"),
        "auto_select_profile":
            MessageLookupByLibrary.simpleMessage("Auto select profile"),
        "automatic": MessageLookupByLibrary.simpleMessage("Automatic"),
        "avatar": MessageLookupByLibrary.simpleMessage("Avatar"),
        "back": MessageLookupByLibrary.simpleMessage("뒤로"),
        "block_rule": MessageLookupByLibrary.simpleMessage("Block Rule"),
        "block_rules": MessageLookupByLibrary.simpleMessage("Block Rules"),
        "blockers": MessageLookupByLibrary.simpleMessage("Blockers"),
        "blurring_cover_background": MessageLookupByLibrary.simpleMessage(
            "Blurring of cover background"),
        "cancel": MessageLookupByLibrary.simpleMessage("취소"),
        "change_to_favorites": MessageLookupByLibrary.simpleMessage("즐겨찾기 변경"),
        "chapter": MessageLookupByLibrary.simpleMessage("Chapter"),
        "check_for_update":
            MessageLookupByLibrary.simpleMessage("Check for Update"),
        "clear_cache": MessageLookupByLibrary.simpleMessage("캐시 지우기"),
        "clear_filter": MessageLookupByLibrary.simpleMessage("지우기"),
        "clear_search_history":
            MessageLookupByLibrary.simpleMessage("검색 기록 지우기"),
        "clipboard_detection": MessageLookupByLibrary.simpleMessage("클립보드 감지"),
        "clipboard_detection_desc": MessageLookupByLibrary.simpleMessage(
            "자동으로 클립보드에 있는 갤러리 링크를 감지합니다."),
        "collapse": MessageLookupByLibrary.simpleMessage("접기"),
        "color_picker_primary": MessageLookupByLibrary.simpleMessage("primary"),
        "color_picker_wheel": MessageLookupByLibrary.simpleMessage("wheel"),
        "comment": MessageLookupByLibrary.simpleMessage("Comment"),
        "commentator": MessageLookupByLibrary.simpleMessage("Commentator"),
        "concurrent_galleries":
            MessageLookupByLibrary.simpleMessage("동시 갤러리 다운로드 수"),
        "copied_to_clipboard":
            MessageLookupByLibrary.simpleMessage("클립보드에 복사되었습니다."),
        "copy": MessageLookupByLibrary.simpleMessage("복사"),
        "current_site": m0,
        "current_version": MessageLookupByLibrary.simpleMessage("현재 버전"),
        "custom_hosts": MessageLookupByLibrary.simpleMessage("사용자 지정 hosts"),
        "custom_width": MessageLookupByLibrary.simpleMessage("Custom Width"),
        "dark": MessageLookupByLibrary.simpleMessage("어둡게"),
        "dark_mode_effect": MessageLookupByLibrary.simpleMessage("다크 모드 효과"),
        "date_or_offset":
            MessageLookupByLibrary.simpleMessage("Date or Offset"),
        "default_avatar_style":
            MessageLookupByLibrary.simpleMessage("Default avatar style"),
        "delete": MessageLookupByLibrary.simpleMessage("지우기"),
        "delete_task": MessageLookupByLibrary.simpleMessage("Delete Task"),
        "delete_task_and_content":
            MessageLookupByLibrary.simpleMessage("Delete task and content"),
        "delete_task_only":
            MessageLookupByLibrary.simpleMessage("Delete task only"),
        "direct": MessageLookupByLibrary.simpleMessage("Direct"),
        "disabled": MessageLookupByLibrary.simpleMessage("비활성화 됨"),
        "domain_fronting": MessageLookupByLibrary.simpleMessage("도메인 프론팅"),
        "donate": MessageLookupByLibrary.simpleMessage("Donate"),
        "done": MessageLookupByLibrary.simpleMessage("완료"),
        "double_click_back":
            MessageLookupByLibrary.simpleMessage("한번 더 누르면 종료됩니다."),
        "double_page_model":
            MessageLookupByLibrary.simpleMessage("Double page model"),
        "download_files_unavailable": MessageLookupByLibrary.simpleMessage("파일을 일시적으로 사용할 수 없습니다"),
    "check_download_files_and_continue": MessageLookupByLibrary.simpleMessage("파일 확인 후 계속"),
    "download": MessageLookupByLibrary.simpleMessage("다운로드"),
        "download_location": MessageLookupByLibrary.simpleMessage("다운로드 경로"),
        "download_ori_image":
            MessageLookupByLibrary.simpleMessage("Download original image"),
        "download_ori_image_summary": MessageLookupByLibrary.simpleMessage(
            "it is dangerous! You may get 509 error"),
        "downloaded": MessageLookupByLibrary.simpleMessage("다운로드 완료"),
        "downloading": MessageLookupByLibrary.simpleMessage("Downloading"),
        "edit": MessageLookupByLibrary.simpleMessage("Edit"),
        "edit_block_rule":
            MessageLookupByLibrary.simpleMessage("Edit Block Rule"),
        "edit_comment": MessageLookupByLibrary.simpleMessage("Edit comment"),
        "eh": MessageLookupByLibrary.simpleMessage("E·H"),
        "ehentai_my_tags": MessageLookupByLibrary.simpleMessage("내 태그"),
        "ehentai_settings": MessageLookupByLibrary.simpleMessage("EHentai 설정"),
        "enable": MessageLookupByLibrary.simpleMessage("Enable"),
        "enter_date_or_offset_or_gid":
            MessageLookupByLibrary.simpleMessage("Enter date or offset or gid"),
        "expand": MessageLookupByLibrary.simpleMessage("펼치기"),
        "experimental_feature":
            MessageLookupByLibrary.simpleMessage("Experimental feature"),
        "export": MessageLookupByLibrary.simpleMessage("Export"),
        "export_app_data":
            MessageLookupByLibrary.simpleMessage("Export App Data"),
        "export_app_data_summary":
            MessageLookupByLibrary.simpleMessage("Export App Data To File"),
        "favcat": MessageLookupByLibrary.simpleMessage("즐겨찾기"),
        "favorites_order": MessageLookupByLibrary.simpleMessage("즐겨찾기 정렬"),
        "favorites_order_Use_favorited":
            MessageLookupByLibrary.simpleMessage("즐겨찾기된 순"),
        "favorites_order_Use_posted":
            MessageLookupByLibrary.simpleMessage("게시된 순"),
        "filter_comments_by_score":
            MessageLookupByLibrary.simpleMessage("Filter Comments By Score"),
        "filter_comments_by_score_summary":
            MessageLookupByLibrary.simpleMessage(
                "Comments below/equal to this score will be hidden"),
        "fixed_height_of_list_items":
            MessageLookupByLibrary.simpleMessage("Fixed height of list items"),
        "follow_system": MessageLookupByLibrary.simpleMessage("시스템 기본값"),
        "fullscreen": MessageLookupByLibrary.simpleMessage("Fullscreen"),
        "galery_site": MessageLookupByLibrary.simpleMessage("갤러리 사이트"),
        "gallery_comments": MessageLookupByLibrary.simpleMessage("갤러리 댓글"),
        "global_setting":
            MessageLookupByLibrary.simpleMessage("Global Setting"),
        "gray_black": MessageLookupByLibrary.simpleMessage("회색 (Gray)"),
        "group": MessageLookupByLibrary.simpleMessage("Group"),
        "groupName": MessageLookupByLibrary.simpleMessage("Group name"),
        "groupType": MessageLookupByLibrary.simpleMessage("Group type"),
        "hide": MessageLookupByLibrary.simpleMessage("Hide"),
        "hide_gallery_thumbnails":
            MessageLookupByLibrary.simpleMessage("Hide Gallery Thumbnails"),
        "hide_thumbnails":
            MessageLookupByLibrary.simpleMessage("Hide Thumbnails"),
        "hide_top_bar_on_scroll":
            MessageLookupByLibrary.simpleMessage("Hide top bar on scroll"),
        "high_resolution_images_limited": MessageLookupByLibrary.simpleMessage(
            "High Resolution Images Limited"),
        "horizontal_thumbnails":
            MessageLookupByLibrary.simpleMessage("Horizontal Thumbnails"),
        "host": MessageLookupByLibrary.simpleMessage("Host"),
        "hours": MessageLookupByLibrary.simpleMessage("시간"),
        "image_block": MessageLookupByLibrary.simpleMessage("Image Hide"),
        "image_download_type":
            MessageLookupByLibrary.simpleMessage("Download type"),
        "image_limits": MessageLookupByLibrary.simpleMessage("Image Limits"),
        "import_app_data":
            MessageLookupByLibrary.simpleMessage("Import App Data"),
        "import_app_data_summary": MessageLookupByLibrary.simpleMessage(
            "Import App Data From Backup File, need restart app"),
        "input_empty": MessageLookupByLibrary.simpleMessage("인풋 비어있음"),
        "input_error": MessageLookupByLibrary.simpleMessage("인풋 에러"),
        "instantly": MessageLookupByLibrary.simpleMessage("즉시"),
        "japanese_title_in_gallery":
            MessageLookupByLibrary.simpleMessage("Japanese Title in Gallery"),
        "japanese_title_in_gallery_summary":
            MessageLookupByLibrary.simpleMessage(
                "Only effective in gallery page"),
        "jump_next": MessageLookupByLibrary.simpleMessage("Next"),
        "jump_or_seek": MessageLookupByLibrary.simpleMessage("Jump or Seek"),
        "jump_prev": MessageLookupByLibrary.simpleMessage("Prev"),
        "jump_to_page": MessageLookupByLibrary.simpleMessage("페이지로 이동"),
        "landscape": MessageLookupByLibrary.simpleMessage("가로"),
        "language": MessageLookupByLibrary.simpleMessage("언어"),
        "last_favorites": MessageLookupByLibrary.simpleMessage(
            "최근 즐겨찾기, 길게 눌러 수동으로 선택할 수 있습니다."),
        "latest_version":
            MessageLookupByLibrary.simpleMessage("Latest version"),
        "layout": MessageLookupByLibrary.simpleMessage("Layout"),
        "left_to_right": MessageLookupByLibrary.simpleMessage("왼쪽에서 오른쪽으로"),
        "license": MessageLookupByLibrary.simpleMessage("License"),
        "light": MessageLookupByLibrary.simpleMessage("밝게"),
        "link_redirect": MessageLookupByLibrary.simpleMessage("Link redirect"),
        "link_redirect_summary": MessageLookupByLibrary.simpleMessage(
            "Redirecting gallery links to selected sites"),
        "list_load_more_fail": MessageLookupByLibrary.simpleMessage(
            "불러오기에 실패하였습니다, 탭하여 다시 로드하세요."),
        "list_mode": MessageLookupByLibrary.simpleMessage("목록 모드"),
        "listmode_grid": MessageLookupByLibrary.simpleMessage("Grid"),
        "listmode_grid_tags": MessageLookupByLibrary.simpleMessage("그리드 - 태그"),
    "listmode_medium": MessageLookupByLibrary.simpleMessage("목록 - 중간"),
        "listmode_small": MessageLookupByLibrary.simpleMessage("목록 - 작게"),
        "listmode_waterfall": MessageLookupByLibrary.simpleMessage("Waterfall"),
        "listmode_waterfall_large":
            MessageLookupByLibrary.simpleMessage("WaterfallFlow - 크게"),
        "loading": MessageLookupByLibrary.simpleMessage("로딩 중"),
        "local_favorite": MessageLookupByLibrary.simpleMessage("로컬 즐겨찾기"),
        "login": MessageLookupByLibrary.simpleMessage("로그인"),
        "login_web": MessageLookupByLibrary.simpleMessage("웹 로그인"),
        "max_history": MessageLookupByLibrary.simpleMessage("최대 방문 기록"),
        "min": MessageLookupByLibrary.simpleMessage("분"),
        "model": m1,
        "more_thumbnails": MessageLookupByLibrary.simpleMessage("미리 보기 더 보기"),
        "multi_download": MessageLookupByLibrary.simpleMessage("다중 다운로드"),
        "mytags_on_website": MessageLookupByLibrary.simpleMessage("사이트에서 설정하기"),
        "native_http_client_adapter":
            MessageLookupByLibrary.simpleMessage("Native HTTP Client Adapter"),
        "never": MessageLookupByLibrary.simpleMessage("Never"),
        "newGroup": MessageLookupByLibrary.simpleMessage("New Group"),
        "newText": MessageLookupByLibrary.simpleMessage("New Text"),
        "new_comment": MessageLookupByLibrary.simpleMessage("New comment"),
        "no": MessageLookupByLibrary.simpleMessage("No"),
        "no_limit": MessageLookupByLibrary.simpleMessage("No Limit"),
        "no_more_thumbnails":
            MessageLookupByLibrary.simpleMessage("미리 보기가 더 없음"),
        "notFav": MessageLookupByLibrary.simpleMessage("즐겨찾기에 없음"),
        "not_login": MessageLookupByLibrary.simpleMessage("로그인하지 않음"),
        "off": MessageLookupByLibrary.simpleMessage("꺼짐"),
        "ok": MessageLookupByLibrary.simpleMessage("확인"),
        "on": MessageLookupByLibrary.simpleMessage("켜짐"),
        "one_step_favorite":
            MessageLookupByLibrary.simpleMessage("One Step Favorite"),
        "one_step_favorite_desc": MessageLookupByLibrary.simpleMessage(
            "Quickly add gallery to favorite, short press to save to the last selected favorite, long press to display the favorite dialog."),
        "open_supported_links":
            MessageLookupByLibrary.simpleMessage("Open supported links"),
        "open_supported_links_summary": MessageLookupByLibrary.simpleMessage(
            "Starting with Android 12, apps can only be used as web link handling apps if they are approved. Otherwise it will be processed using the default browser. You can manually approve it here"),
        "open_with_other_apps":
            MessageLookupByLibrary.simpleMessage("Open with other apps"),
        "orientation_auto": MessageLookupByLibrary.simpleMessage("자동"),
        "orientation_landscapeLeft": MessageLookupByLibrary.simpleMessage("가로"),
        "orientation_landscapeRight":
            MessageLookupByLibrary.simpleMessage("뒤집힌 가로"),
        "orientation_portraitUp": MessageLookupByLibrary.simpleMessage("세로"),
        "orientation_system": MessageLookupByLibrary.simpleMessage("시스템 방향"),
        "original_image": MessageLookupByLibrary.simpleMessage("Original"),
        "p_Archiver": MessageLookupByLibrary.simpleMessage("아카이브"),
        "p_Download": MessageLookupByLibrary.simpleMessage("다운로드"),
        "p_Rate": MessageLookupByLibrary.simpleMessage("평가"),
        "p_Similar": MessageLookupByLibrary.simpleMessage("유사"),
        "p_Torrent": MessageLookupByLibrary.simpleMessage("토렌트"),
        "page_range": MessageLookupByLibrary.simpleMessage("페이지 범위"),
        "page_range_error": MessageLookupByLibrary.simpleMessage("페이지 범위 오류"),
        "page_view_type":
            MessageLookupByLibrary.simpleMessage("Page View Type"),
        "passwd": MessageLookupByLibrary.simpleMessage("비밀번호"),
        "paused": MessageLookupByLibrary.simpleMessage("Paused"),
        "phash_block_list":
            MessageLookupByLibrary.simpleMessage("Perceptual Hash Block List"),
        "phash_check": MessageLookupByLibrary.simpleMessage(
            "Perceptual Hash Check (Block similar images)"),
        "pls_i_passwd": MessageLookupByLibrary.simpleMessage("비밀번호를 입력하여 주세요."),
        "pls_i_username":
            MessageLookupByLibrary.simpleMessage("사용자 이름을 입력하여 주세요."),
        "port": MessageLookupByLibrary.simpleMessage("Port"),
        "preload_image": MessageLookupByLibrary.simpleMessage("이미지 미리 불러오기"),
        "processing": MessageLookupByLibrary.simpleMessage("처리 중"),
        "proxy": MessageLookupByLibrary.simpleMessage("Proxy"),
        "proxy_type": MessageLookupByLibrary.simpleMessage("Proxy Type"),
        "pure_black": MessageLookupByLibrary.simpleMessage("검정색 (Pure)"),
        "quick_search": MessageLookupByLibrary.simpleMessage("빠른 검색"),
        "read": MessageLookupByLibrary.simpleMessage("읽기"),
        "read_from_clipboard":
            MessageLookupByLibrary.simpleMessage("Read from clipboard"),
        "read_setting": MessageLookupByLibrary.simpleMessage("읽기 설정"),
        "read_view_compatible_mode":
            MessageLookupByLibrary.simpleMessage("Compatible Mode"),
        "reading_direction": MessageLookupByLibrary.simpleMessage("읽기 방향"),
        "rebuild_tasks_data":
            MessageLookupByLibrary.simpleMessage("Rebuild tasks data"),
        "redirect_thumb_link":
            MessageLookupByLibrary.simpleMessage("Redirect Thumb Link"),
        "redirect_thumb_link_summary": MessageLookupByLibrary.simpleMessage(
            "Redirect Thumb Link To ehgt.org"),
        "redownload": MessageLookupByLibrary.simpleMessage("Redownload"),
        "refresh_igneous":
            MessageLookupByLibrary.simpleMessage("Refresh Igneous"),
        "regex": MessageLookupByLibrary.simpleMessage("Regex"),
        "regex_format_error":
            MessageLookupByLibrary.simpleMessage("Regex format error"),
        "reload_image": MessageLookupByLibrary.simpleMessage("이미지 새로고침"),
        "remove_from_favorites":
            MessageLookupByLibrary.simpleMessage("즐겨찾기에서 제거"),
        "reply_to_comment": MessageLookupByLibrary.simpleMessage("Reply"),
        "resample_image": MessageLookupByLibrary.simpleMessage("Resample"),
        "reset_cost": MessageLookupByLibrary.simpleMessage("Reset Cost"),
        "restore_tasks_data":
            MessageLookupByLibrary.simpleMessage("Restore tasks data"),
        "right_to_left": MessageLookupByLibrary.simpleMessage("오른쪽에서 왼쪽으로"),
        "s_Advanced_Options": MessageLookupByLibrary.simpleMessage("고급 설정"),
        "s_Between": MessageLookupByLibrary.simpleMessage("사이"),
        "s_Disable_default_filters":
            MessageLookupByLibrary.simpleMessage("기본 필터 끄기"),
        "s_Minimum_Rating": MessageLookupByLibrary.simpleMessage("최소 평점"),
        "s_Only_Show_Galleries_With_Torrents":
            MessageLookupByLibrary.simpleMessage("토렌트 파일이 있는 갤러리만 검색"),
        "s_Search_Downvoted_Tags":
            MessageLookupByLibrary.simpleMessage("Downvoted 태그 검색"),
        "s_Search_Fav_Name": MessageLookupByLibrary.simpleMessage("이름 검색"),
        "s_Search_Fav_Note": MessageLookupByLibrary.simpleMessage("노트 검색"),
        "s_Search_Fav_Tags": MessageLookupByLibrary.simpleMessage("태그 검색"),
        "s_Search_Gallery_Description":
            MessageLookupByLibrary.simpleMessage("갤러리 설명 검색"),
        "s_Search_Gallery_Name":
            MessageLookupByLibrary.simpleMessage("갤러리 이름 검색"),
        "s_Search_Gallery_Tags":
            MessageLookupByLibrary.simpleMessage("갤러리 태그 검색"),
        "s_Search_Low_Power_Tags":
            MessageLookupByLibrary.simpleMessage("Low-Power 태그 검색"),
        "s_Search_Torrent_Filenames":
            MessageLookupByLibrary.simpleMessage("토렌트 파일 이름 검색"),
        "s_Show_Expunged_Galleries":
            MessageLookupByLibrary.simpleMessage("Expunged 갤러리 표시"),
        "s_and": MessageLookupByLibrary.simpleMessage("그리고"),
        "s_pages": MessageLookupByLibrary.simpleMessage("페이지"),
        "s_stars": m2,
        "save": MessageLookupByLibrary.simpleMessage("Save"),
        "save_into_album": MessageLookupByLibrary.simpleMessage("앨범에 저장"),
        "saved_successfully": MessageLookupByLibrary.simpleMessage("저장 완료"),
        "screen_orientation": MessageLookupByLibrary.simpleMessage("화면 방향"),
        "search": MessageLookupByLibrary.simpleMessage("검색"),
        "searchTexts": MessageLookupByLibrary.simpleMessage("Search texts"),
        "search_history": MessageLookupByLibrary.simpleMessage("검색 기록"),
        "search_type": MessageLookupByLibrary.simpleMessage("검색 종류"),
        "second": MessageLookupByLibrary.simpleMessage("초"),
        "security": MessageLookupByLibrary.simpleMessage("보안"),
        "security_blurredInRecentTasks":
            MessageLookupByLibrary.simpleMessage("최근 앱에서 블러 처리"),
        "setting_on_website":
            MessageLookupByLibrary.simpleMessage("사이트에서 설정하기"),
        "share": MessageLookupByLibrary.simpleMessage("공유"),
        "share_image": MessageLookupByLibrary.simpleMessage("이미지 공유"),
        "show_comment_avatar":
            MessageLookupByLibrary.simpleMessage("Show comment avatar"),
        "show_comments": MessageLookupByLibrary.simpleMessage("Show Comments"),
        "show_filter": MessageLookupByLibrary.simpleMessage("필터 표시"),
        "show_gallery_tags":
            MessageLookupByLibrary.simpleMessage("Show Gallery Tags"),
        "show_jpn_title": MessageLookupByLibrary.simpleMessage("일본어 제목 표시"),
        "show_only_uploader_comment":
            MessageLookupByLibrary.simpleMessage("Show Only Uploader Comment"),
        "show_page_interval": MessageLookupByLibrary.simpleMessage("페이지 간격 표시"),
        "skip": MessageLookupByLibrary.simpleMessage("Skip"),
        "slide_out_page":
            MessageLookupByLibrary.simpleMessage("Slide Out Page"),
        "sync_group": MessageLookupByLibrary.simpleMessage("Sync group"),
        "sync_history": MessageLookupByLibrary.simpleMessage("Sync history"),
        "sync_quick_search":
            MessageLookupByLibrary.simpleMessage("Sync quick search"),
        "sync_read_progress":
            MessageLookupByLibrary.simpleMessage("Sync read progress"),
        "system_proxy": MessageLookupByLibrary.simpleMessage("System Proxy"),
        "system_share": MessageLookupByLibrary.simpleMessage("시스템 공유"),
        "t_Clear_all_history":
            MessageLookupByLibrary.simpleMessage("모든 기록 지우기"),
        "tab_download": MessageLookupByLibrary.simpleMessage("다운로드"),
        "tab_favorite": MessageLookupByLibrary.simpleMessage("즐겨찾기"),
        "tab_gallery": MessageLookupByLibrary.simpleMessage("갤러리"),
        "tab_history": MessageLookupByLibrary.simpleMessage("방문 기록"),
        "tab_popular": MessageLookupByLibrary.simpleMessage("인기"),
        "tab_setting": MessageLookupByLibrary.simpleMessage("설정"),
        "tab_sort": MessageLookupByLibrary.simpleMessage("길게 누르고 끌어서 정렬"),
        "tab_toplist": MessageLookupByLibrary.simpleMessage("Toplists"),
        "tab_watched": MessageLookupByLibrary.simpleMessage("Watched"),
        "tabbar_setting": MessageLookupByLibrary.simpleMessage("탭바 설정"),
        "tablet_layout": MessageLookupByLibrary.simpleMessage("Tablet layout"),
        "tagNamespace": m3,
        "tag_add_to_mytag":
            MessageLookupByLibrary.simpleMessage("Add to mytags"),
        "tag_dialog_Default_color":
            MessageLookupByLibrary.simpleMessage("Default color"),
        "tag_dialog_Hide": MessageLookupByLibrary.simpleMessage("Hide"),
        "tag_dialog_TagColor": MessageLookupByLibrary.simpleMessage("Color"),
        "tag_dialog_Watch": MessageLookupByLibrary.simpleMessage("Watch"),
        "tag_dialog_tagWeight":
            MessageLookupByLibrary.simpleMessage("Tag Weight"),
        "tag_limit": MessageLookupByLibrary.simpleMessage("Tag Limit"),
        "tag_vote_down": MessageLookupByLibrary.simpleMessage("비추천"),
        "tag_vote_up": MessageLookupByLibrary.simpleMessage("추천"),
        "tag_withdraw_vote": MessageLookupByLibrary.simpleMessage("추천 취소"),
        "tags": MessageLookupByLibrary.simpleMessage("태그"),
        "tap_to_turn_page_anima":
            MessageLookupByLibrary.simpleMessage("Tap to turn page animations"),
        "theme": MessageLookupByLibrary.simpleMessage("테마"),
        "thumbnails": MessageLookupByLibrary.simpleMessage("미리 보기"),
        "title": MessageLookupByLibrary.simpleMessage("Title"),
        "tolist_alltime": MessageLookupByLibrary.simpleMessage("All-Time"),
        "tolist_past_month": MessageLookupByLibrary.simpleMessage("Past Month"),
        "tolist_past_year": MessageLookupByLibrary.simpleMessage("Past Year"),
        "tolist_yesterday": MessageLookupByLibrary.simpleMessage("Yesterday"),
        "top_to_bottom": MessageLookupByLibrary.simpleMessage("위에서 아래로"),
        "turn_page_anima":
            MessageLookupByLibrary.simpleMessage("Turn page animations"),
        "uc_Chinese": MessageLookupByLibrary.simpleMessage("Chinese"),
        "uc_Dutch": MessageLookupByLibrary.simpleMessage("Dutch"),
        "uc_English": MessageLookupByLibrary.simpleMessage("English"),
        "uc_French": MessageLookupByLibrary.simpleMessage("French"),
        "uc_German": MessageLookupByLibrary.simpleMessage("German"),
        "uc_Hungarian": MessageLookupByLibrary.simpleMessage("Hungarian"),
        "uc_Italian": MessageLookupByLibrary.simpleMessage("Italian"),
        "uc_Japanese": MessageLookupByLibrary.simpleMessage("Japanese"),
        "uc_Korean": MessageLookupByLibrary.simpleMessage("Korean"),
        "uc_NA": MessageLookupByLibrary.simpleMessage("N/A"),
        "uc_Original": MessageLookupByLibrary.simpleMessage("Original"),
        "uc_Other": MessageLookupByLibrary.simpleMessage("Other"),
        "uc_Polish": MessageLookupByLibrary.simpleMessage("Polish"),
        "uc_Portuguese": MessageLookupByLibrary.simpleMessage("Portuguese"),
        "uc_Rewrite": MessageLookupByLibrary.simpleMessage("Rewrite"),
        "uc_Russian": MessageLookupByLibrary.simpleMessage("Russian"),
        "uc_Spanish": MessageLookupByLibrary.simpleMessage("Spanish"),
        "uc_Thai": MessageLookupByLibrary.simpleMessage("Thai"),
        "uc_Translated": MessageLookupByLibrary.simpleMessage("Translated"),
        "uc_Vietnamese": MessageLookupByLibrary.simpleMessage("Vietnamese"),
        "uc_ar_0": MessageLookupByLibrary.simpleMessage(
            "Manual Select, Manual Start (Default)"),
        "uc_ar_1":
            MessageLookupByLibrary.simpleMessage("Manual Select, Auto Start"),
        "uc_ar_2": MessageLookupByLibrary.simpleMessage(
            "Auto Select Original, Manual Start"),
        "uc_ar_3": MessageLookupByLibrary.simpleMessage(
            "Auto Select Original, Auto Start"),
        "uc_ar_4": MessageLookupByLibrary.simpleMessage(
            "Auto Select Resample, Manual Start"),
        "uc_ar_5": MessageLookupByLibrary.simpleMessage(
            "Auto Select Resample, Auto Start"),
        "uc_archiver_desc": MessageLookupByLibrary.simpleMessage(
            "The default behavior for the Archiver is to confirm the cost and selection for original or resampled archive, then present a link that can be clicked or copied elsewhere. You can change this behavior here."),
        "uc_archiver_set":
            MessageLookupByLibrary.simpleMessage("rchiver Settings"),
        "uc_artist": MessageLookupByLibrary.simpleMessage("rtist"),
        "uc_auto": MessageLookupByLibrary.simpleMessage("Auto"),
        "uc_character": MessageLookupByLibrary.simpleMessage("character"),
        "uc_comments_show_votes":
            MessageLookupByLibrary.simpleMessage("Show votes"),
        "uc_comments_sort_order":
            MessageLookupByLibrary.simpleMessage("Sort order"),
        "uc_crt_profile": MessageLookupByLibrary.simpleMessage("Create New"),
        "uc_cs_0":
            MessageLookupByLibrary.simpleMessage("Oldest comments first"),
        "uc_cs_1":
            MessageLookupByLibrary.simpleMessage("Recent comments first"),
        "uc_cs_2": MessageLookupByLibrary.simpleMessage("By highest score"),
        "uc_del_profile":
            MessageLookupByLibrary.simpleMessage("Delete Profile"),
        "uc_dm_0": MessageLookupByLibrary.simpleMessage("Compact"),
        "uc_dm_1": MessageLookupByLibrary.simpleMessage("Thumbnail"),
        "uc_dm_2": MessageLookupByLibrary.simpleMessage("Extended"),
        "uc_dm_3": MessageLookupByLibrary.simpleMessage("Minimal"),
        "uc_dm_4": MessageLookupByLibrary.simpleMessage("Minimal+"),
        "uc_exc_lang":
            MessageLookupByLibrary.simpleMessage("Excluded Languages"),
        "uc_exc_lang_desc": MessageLookupByLibrary.simpleMessage(
            "If you wish to hide galleries in certain languages from the gallery list and searches, select them from the list abover.\nNote that matching galleries will never appear regardless of your search query."),
        "uc_exc_up": MessageLookupByLibrary.simpleMessage("Excluded Uploaders"),
        "uc_exc_up_desc": MessageLookupByLibrary.simpleMessage(
            "If you wish to hide galleries from certain uploaders from the gallery list and searches, add them abover. Put one username per line.\nNote that galleries from these uploaders will never appear regardless of your search query."),
        "uc_fav": MessageLookupByLibrary.simpleMessage("Favorites"),
        "uc_fav_sort": MessageLookupByLibrary.simpleMessage("Default sort"),
        "uc_fav_sort_desc": MessageLookupByLibrary.simpleMessage(
            "You can also select your default sort order for galleries on your favorites page. Note that favorites added prior to the March 2016 revamp did not store a timestamp, and will use the gallery posted time regardless of this setting."),
        "uc_female": MessageLookupByLibrary.simpleMessage("female"),
        "uc_front_page": MessageLookupByLibrary.simpleMessage("Front Page"),
        "uc_front_page_dis_mode":
            MessageLookupByLibrary.simpleMessage("Front Page Display mode"),
        "uc_fs_0":
            MessageLookupByLibrary.simpleMessage("By last gallery update time"),
        "uc_fs_1": MessageLookupByLibrary.simpleMessage("By favorited time"),
        "uc_gallery_comments":
            MessageLookupByLibrary.simpleMessage("Gallery Comments"),
        "uc_group": MessageLookupByLibrary.simpleMessage("group"),
        "uc_hath_local_host": MessageLookupByLibrary.simpleMessage(
            "Hentai@Home Local Network Host"),
        "uc_hath_local_host_desc": MessageLookupByLibrary.simpleMessage(
            "    This setting can be used if you have a H@H client running on your local network with the same public IP you browse the site with. Some routers are buggy and cannot route requests back to its own IP; this allows you to work around this problem.\n    If you are running the client on the same PC you browse from, use the loopback address (127.0.0.1:port). If the client is running on another computer on your network, use its local network IP. Some browser configurations prevent external web sites from accessing URLs with local network IPs, the site must then be whitelisted for this to work."),
        "uc_img_cussize_desc": MessageLookupByLibrary.simpleMessage(
            "While the site will automatically scale down images to fit your screen width, you can also manually restrict the maximum display size of an image. Like the automatic scaling, this does not resample the image, as the resizing is done browser-side. (0 = no limit)"),
        "uc_img_horiz": MessageLookupByLibrary.simpleMessage("Horizontal"),
        "uc_img_load_setting":
            MessageLookupByLibrary.simpleMessage("Image Load Settings"),
        "uc_img_size_setting":
            MessageLookupByLibrary.simpleMessage("Image Size Settings"),
        "uc_img_vert": MessageLookupByLibrary.simpleMessage("Vertical"),
        "uc_ip_addr_port":
            MessageLookupByLibrary.simpleMessage("IP Address:Port"),
        "uc_language": MessageLookupByLibrary.simpleMessage("language"),
        "uc_lt_0": MessageLookupByLibrary.simpleMessage(
            "On mouse-over (pages load faster, but there may be a slight delay before a thumb appears)"),
        "uc_lt_0_s": MessageLookupByLibrary.simpleMessage("On mouse-over"),
        "uc_lt_1": MessageLookupByLibrary.simpleMessage(
            "On page load (pages take longer to load, but there is no delay for loading a thumb after the page has loaded)"),
        "uc_lt_1_s": MessageLookupByLibrary.simpleMessage("On page load"),
        "uc_male": MessageLookupByLibrary.simpleMessage("male"),
        "uc_mose_over_thumb":
            MessageLookupByLibrary.simpleMessage("mouse-over thumbnails"),
        "uc_mpv": MessageLookupByLibrary.simpleMessage("Multi-Page Viewer"),
        "uc_mpv_always": MessageLookupByLibrary.simpleMessage("Always use"),
        "uc_mpv_stype": MessageLookupByLibrary.simpleMessage("Display Style"),
        "uc_mpv_thumb_pane":
            MessageLookupByLibrary.simpleMessage("Thumbnail Pane"),
        "uc_ms_0": MessageLookupByLibrary.simpleMessage(
            "Align left;\nOnly scale if image is larger than browser width"),
        "uc_ms_1": MessageLookupByLibrary.simpleMessage(
            "Align center;\nOnly scale if image is larger than browser width"),
        "uc_ms_2": MessageLookupByLibrary.simpleMessage(
            "Align center;\nAlways scale images to fit browser width"),
        "uc_mt_0": MessageLookupByLibrary.simpleMessage("Show"),
        "uc_mt_1": MessageLookupByLibrary.simpleMessage("Hide"),
        "uc_name_display":
            MessageLookupByLibrary.simpleMessage("Gallery Name Display"),
        "uc_name_display_desc": MessageLookupByLibrary.simpleMessage(
            "Many galleries have both an English/Romanized title and a title in Japanese script. Which gallery name would you like as default?"),
        "uc_oi_0":
            MessageLookupByLibrary.simpleMessage("Prefer resampled images"),
        "uc_oi_1":
            MessageLookupByLibrary.simpleMessage("Prefer original images"),
        "uc_ori_image": MessageLookupByLibrary.simpleMessage("Original Images"),
        "uc_ori_image_desc": MessageLookupByLibrary.simpleMessage(
            "Use original images instead of the resampled versions? Resampled images will still be used if you select a horizonal resolution different than \"Auto\" above and the image in question is wider, or if the original image is larger than 10 MiB (or 4 MiB for galleries older than one year)."),
        "uc_parody": MessageLookupByLibrary.simpleMessage("parody"),
        "uc_pixels": MessageLookupByLibrary.simpleMessage("pixels"),
        "uc_pn_0": MessageLookupByLibrary.simpleMessage("None"),
        "uc_pn_1": MessageLookupByLibrary.simpleMessage("Page Number Only"),
        "uc_pn_2": MessageLookupByLibrary.simpleMessage("Page Number + Name"),
        "uc_profile": MessageLookupByLibrary.simpleMessage("Profile"),
        "uc_qb_0": MessageLookupByLibrary.simpleMessage("Nope"),
        "uc_qb_1": MessageLookupByLibrary.simpleMessage("Yup"),
        "uc_rating": MessageLookupByLibrary.simpleMessage("Ratings Colors"),
        "uc_rating_desc": MessageLookupByLibrary.simpleMessage(
            "    By default, galleries that you have rated will appear with red stars for ratings of 2 stars and below, green for ratings between 2.5 and 4 stars, and blue for ratings of 4.5 or 5 stars. You can customize this by entering your desired color combination below.\n    Each letter represents one star. The default RRGGB means R(ed) for the first and second star, G(reen) for the third and fourth, and B(lue) for the fifth. You can also use (Y)ellow for the normal stars. Any five-letter R/G/B/Y combo works."),
        "uc_reclass": MessageLookupByLibrary.simpleMessage("reclass"),
        "uc_rename": MessageLookupByLibrary.simpleMessage("Rename"),
        "uc_res_res":
            MessageLookupByLibrary.simpleMessage("Resample Resolution"),
        "uc_res_res_desc": MessageLookupByLibrary.simpleMessage(
            "Images are normally resampled to 1280 pixels of horizontal resolution for online viewing. You can select one of the above alternative resolutions."),
        "uc_sc_0":
            MessageLookupByLibrary.simpleMessage("On score hover or click"),
        "uc_sc_1": MessageLookupByLibrary.simpleMessage("Always"),
        "uc_search_r_count":
            MessageLookupByLibrary.simpleMessage("Search Result Count"),
        "uc_search_r_count_desc": MessageLookupByLibrary.simpleMessage(
            "How many results would you like per page for the index/search page and torrent search pages? (Hath Perk: Paging Enlargement Required)"),
        "uc_selected": MessageLookupByLibrary.simpleMessage("Selected"),
        "uc_set_as_def": MessageLookupByLibrary.simpleMessage("Set as Default"),
        "uc_show_page_num":
            MessageLookupByLibrary.simpleMessage("Thumbnail Labeling"),
        "uc_tag": MessageLookupByLibrary.simpleMessage("Gallery Tags"),
        "uc_tag_ft":
            MessageLookupByLibrary.simpleMessage("Tag Filtering Threshold"),
        "uc_tag_ft_desc": MessageLookupByLibrary.simpleMessage(
            "You can soft filter tags by adding them to My Tags with a negative weight. If a gallery has tags that add up to weight abover this value, it is filtered from view. This threshold can be set between 0 and -9999."),
        "uc_tag_namesp": MessageLookupByLibrary.simpleMessage("Tag Namespaces"),
        "uc_tag_short_order":
            MessageLookupByLibrary.simpleMessage("Gallery Tags Sort order"),
        "uc_tag_wt":
            MessageLookupByLibrary.simpleMessage("Tag Watching Threshold"),
        "uc_tag_wt_desc": MessageLookupByLibrary.simpleMessage(
            "Recently uploaded galleries will be included on the watched screen if it has at least one watched tag with positive weight, and the sum of weights on its watched tags add up to this value or higher. This threshold can be set between 0 and 9999."),
        "uc_tb_0": MessageLookupByLibrary.simpleMessage("Alphabetical"),
        "uc_tb_1": MessageLookupByLibrary.simpleMessage("By tag power"),
        "uc_thor_hath": MessageLookupByLibrary.simpleMessage("Through the H@H"),
        "uc_thumb_row": MessageLookupByLibrary.simpleMessage("Row"),
        "uc_thumb_scaling":
            MessageLookupByLibrary.simpleMessage("Thumbnail Scaling"),
        "uc_thumb_scaling_desc": MessageLookupByLibrary.simpleMessage(
            "Thumbnails on the thumbnail and extended gallery list views can be scaled to a custom value between 75% and 150%."),
        "uc_thumb_setting":
            MessageLookupByLibrary.simpleMessage("Thumbnail Settings"),
        "uc_thumb_size": MessageLookupByLibrary.simpleMessage("Size"),
        "uc_tl_0": MessageLookupByLibrary.simpleMessage("Default Title"),
        "uc_tl_1": MessageLookupByLibrary.simpleMessage(
            " Japanese Title (if available)"),
        "uc_ts_0": MessageLookupByLibrary.simpleMessage("Auto"),
        "uc_ts_1": MessageLookupByLibrary.simpleMessage("Normal"),
        "uc_ts_2": MessageLookupByLibrary.simpleMessage("Small"),
        "uc_uh_0":
            MessageLookupByLibrary.simpleMessage("Any client (Recommended)"),
        "uc_uh_0_s": MessageLookupByLibrary.simpleMessage("Any client"),
        "uc_uh_1": MessageLookupByLibrary.simpleMessage(
            "Default port clients only (Can be slower. Enable if behind firewall/proxy that blocks outgoing non-standard ports.)"),
        "uc_uh_1_s":
            MessageLookupByLibrary.simpleMessage("Default port clients only"),
        "uc_uh_2": MessageLookupByLibrary.simpleMessage(
            "No [Modern/HTTPS] (Donator only. You will not be able to browse as many pages. Recommended only if having severe problems.)"),
        "uc_uh_2_s": MessageLookupByLibrary.simpleMessage("No [Modern/HTTPS]"),
        "uc_uh_3": MessageLookupByLibrary.simpleMessage(
            "No [Legacy/HTTP] (Donator only. May not work by default in modern browsers. Recommended for legacy/outdated browsers only.)"),
        "uc_uh_3_s": MessageLookupByLibrary.simpleMessage("No [Legacy/HTTP]"),
        "uc_viewport_or":
            MessageLookupByLibrary.simpleMessage("Viewport Override"),
        "uc_viewport_or_desc": MessageLookupByLibrary.simpleMessage(
            "Allows you to override the virtual width of the site for mobile devices. This is normally determined automatically by your device based on its DPI. Sensible values at 100% thumbnail scale are between 640 and 1400."),
        "uc_xt_desc": MessageLookupByLibrary.simpleMessage(
            "If you want to exclude certain namespaces from a default tag search, you can check those abover. Note that this does not prevent galleries with tags in these namespaces from appearing, it just makes it so that when searching tags, it will forego those namespaces."),
        "unlimited": MessageLookupByLibrary.simpleMessage("제한 없음"),
        "update_to_version": m4,
        "uploader": MessageLookupByLibrary.simpleMessage("업로더"),
        "user_login": MessageLookupByLibrary.simpleMessage("로그인"),
        "user_name": MessageLookupByLibrary.simpleMessage("사용자 이름"),
        "version": MessageLookupByLibrary.simpleMessage("Version"),
        "vibrate_feedback": MessageLookupByLibrary.simpleMessage("진동 피드백"),
        "volume_key_turn_page":
            MessageLookupByLibrary.simpleMessage("Volume key to turn page"),
        "vote_down_successfully":
            MessageLookupByLibrary.simpleMessage("비추천 성공"),
        "vote_successfully": MessageLookupByLibrary.simpleMessage("추천 성공"),
        "vote_up_successfully": MessageLookupByLibrary.simpleMessage("추천 성공"),
        "webdav_Account":
            MessageLookupByLibrary.simpleMessage("WebDAV Account"),
        "webdav_max_connections":
            MessageLookupByLibrary.simpleMessage("WebDAV Max Connections"),
        "welcome_text": MessageLookupByLibrary.simpleMessage("oh~ oh~ oh~~~"),
        "reader_fill_landscape": MessageLookupByLibrary.simpleMessage("가로 모드 전체 화면"),
        "reader_fill_portrait": MessageLookupByLibrary.simpleMessage("세로 모드 전체 화면"),
        "reader_fill_footer": MessageLookupByLibrary.simpleMessage("해당 방향으로 읽을 때 상태 표시줄을 숨기고 이미지를 안전 영역을 무시하여 화면 가득 표시합니다"),
        "reader_page_layout": MessageLookupByLibrary.simpleMessage("페이지 레이아웃"),
        "reader_surface_tabletop": MessageLookupByLibrary.simpleMessage("테이블톱"),
        "reader_surface_standard": MessageLookupByLibrary.simpleMessage("표준"),
        "reader_single_page": MessageLookupByLibrary.simpleMessage("단일 페이지"),
        "reader_double_odd_left": MessageLookupByLibrary.simpleMessage("두 페이지 (홀수 왼쪽)"),
        "reader_double_even_left": MessageLookupByLibrary.simpleMessage("두 페이지 (짝수 왼쪽)"),
        "reader_auto_read": MessageLookupByLibrary.simpleMessage("자동 넘김"),
        "reader_auto_read_interval": MessageLookupByLibrary.simpleMessage("넘김 간격"),
        "reader_interval_seconds": m5,
        "reader_custom_interval": MessageLookupByLibrary.simpleMessage("사용자 지정…"),
        "full_title": MessageLookupByLibrary.simpleMessage("전체 제목"),
        "group_management": MessageLookupByLibrary.simpleMessage("그룹 관리"),
        "choose_favcat": MessageLookupByLibrary.simpleMessage("즐겨찾기 폴더 선택"),
        "back_to_top": MessageLookupByLibrary.simpleMessage("맨 위로"),
        "ranking_period": MessageLookupByLibrary.simpleMessage("순위 기간"),
        "continue_reading_page": m6,
        "see_all": MessageLookupByLibrary.simpleMessage("모두 보기"),
        "page_count": m7,
        "comment_count": m8,
        "more_actions": MessageLookupByLibrary.simpleMessage("더 보기"),
        "copy_link": MessageLookupByLibrary.simpleMessage("링크 복사"),
        "file_size": MessageLookupByLibrary.simpleMessage("크기"),
        "detail_ambient_background": MessageLookupByLibrary.simpleMessage("상세 페이지 배경"),
        "english_title": MessageLookupByLibrary.simpleMessage("영어 제목"),
        "japanese_title": MessageLookupByLibrary.simpleMessage("일본어 제목"),
        "title_showing": MessageLookupByLibrary.simpleMessage("표시 중"),
        "show_english_title": MessageLookupByLibrary.simpleMessage("영어 제목 보기"),
        "show_japanese_title": MessageLookupByLibrary.simpleMessage("일본어 제목 보기"),
        "search_title": MessageLookupByLibrary.simpleMessage("제목 검색"),
        "copy_title": MessageLookupByLibrary.simpleMessage("제목 복사"),
        "appearance_and_layout": MessageLookupByLibrary.simpleMessage("모양 및 레이아웃"),
        "setting_site": MessageLookupByLibrary.simpleMessage("사이트"),
        "setting_group_browse": MessageLookupByLibrary.simpleMessage("탐색"),
        "setting_group_content": MessageLookupByLibrary.simpleMessage("콘텐츠"),
        "setting_group_system": MessageLookupByLibrary.simpleMessage("시스템"),
        "add": MessageLookupByLibrary.simpleMessage("추가"),
        "auto_scroll": MessageLookupByLibrary.simpleMessage("자동 스크롤"),
        "reload": MessageLookupByLibrary.simpleMessage("새로고침"),
        "card_style": MessageLookupByLibrary.simpleMessage("카드 스타일"),
        "card_style_standard": MessageLookupByLibrary.simpleMessage("표준"),
        "card_style_immersive": MessageLookupByLibrary.simpleMessage("몰입형"),
        "card_style_standard_detail": MessageLookupByLibrary.simpleMessage("표지, 제목, 정보, 태그"),
        "card_style_immersive_detail": MessageLookupByLibrary.simpleMessage("표지만 표시하고 제목과 평점을 표지 위에 표시"),
        "gallery_info": MessageLookupByLibrary.simpleMessage("갤러리 정보"),
        "search_by_image": MessageLookupByLibrary.simpleMessage("이미지로 검색"),
        "remove_all": MessageLookupByLibrary.simpleMessage("모두 삭제"),
        "import_export": MessageLookupByLibrary.simpleMessage("가져오기 및 내보내기"),
        "card_size": MessageLookupByLibrary.simpleMessage("카드 크기"),
        "card_size_small": MessageLookupByLibrary.simpleMessage("작게"),
        "card_size_smaller": MessageLookupByLibrary.simpleMessage("조금 작게"),
        "card_size_standard": MessageLookupByLibrary.simpleMessage("표준"),
        "card_size_larger": MessageLookupByLibrary.simpleMessage("조금 크게"),
        "card_size_large": MessageLookupByLibrary.simpleMessage("크게"),
        "card_size_footer": MessageLookupByLibrary.simpleMessage("열 수는 목록이 있는 영역의 실제 너비로 계산되므로 화면 전환, 회전, 구분선 드래그에 따라 자동으로 바뀝니다. '표준'은 기존 자동 열 수와 같습니다."),
        "outer_display": MessageLookupByLibrary.simpleMessage("외부 디스플레이"),
        "inner_display": MessageLookupByLibrary.simpleMessage("내부 디스플레이"),
        "portrait": MessageLookupByLibrary.simpleMessage("세로"),
        "column_count": m9,
        "column_range": m10,
        "split_follows_divider": MessageLookupByLibrary.simpleMessage("분할 · 구분선에 따름")
      };
}
