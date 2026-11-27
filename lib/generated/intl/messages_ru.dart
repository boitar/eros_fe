// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
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
  String get localeName => 'ru';

  static String m0(count) => "Столбцов: ${count}";

  static String m1(min, max) => "Столбцов: ${min}–${max}";

  static String m2(count) => "Комментарии: ${count}";

  static String m3(page) => "Продолжить · стр. ${page}";

  static String m4(site) => "Текущий ${site}";

  static String m5(reused) => "Повторно: ${reused}";

  static String m6(checked, found, failed) =>
      "Проверено ${checked} · обновлений ${found} (ошибок: ${failed})";

  static String m7(count) => "Найдены новые версии для ${count} галерей";

  static String m8(gid) => "Родитель #${gid}";

  static String m9(count) => "Оценок: ${count}";

  static String m10(count) => "Новых версий: ${count}";

  static String m11(gid) => "Текущая версия #${gid}";

  static String m12(value) => "Пик ${value}";

  static String m13(value) => "Средн. ${value}";

  static String m14(period, percent) => "${period} · ${percent}%";

  static String m15(value) => "Всего ${value}";

  static String m16(score) => "Счёт ${score}";

  static String m17(date) => "Обновлено ${date}";

  static String m18(gid, reused) =>
      "Обновлено локально до #${gid} (повторно: ${reused} стр.)";

  static String m19(gid) =>
      "Повторно использовать неизменённые файлы, обновить задачу до #${gid} и перенести прогресс чтения.";

  static String m20(gid) =>
      "Создать новую папку для #${gid} с повторным использованием файлов, сохранив старую версию.";

  static String m21(count) => "Скачать ${count} стр.";

  static String m22(count) => "Обновить на месте · скачать ${count} стр.";

  static String m23(count) => "Новая задача · скачать ${count} стр.";

  static String m24(count) => "Новая задача целиком · ${count} стр.";

  static String m25(reused, fetch) =>
      "Обновление запущено (повторно: ${reused}, загрузка: ${fetch})";

  static String m26(modelName) => "Модель ${modelName}";

  static String m27(count) => "${count} стр.";

  static String m28(seconds) => "${seconds} с";

  static String m29(page, total) => "Стр. ${page} из ${total}";

  static String m30(rating) => "${rating} ⭐";

  static String m31(tag) => "Добавить ${tag}";

  static String m32(count) => "Всего ${count} стр.";

  static String m33(avg, count) => "Средняя ${avg} · ${count} оценок";

  static String m34(text) => "Искать «${text}»";

  static String m35(count) => "Добавлено: ${count} · через запятую";

  static String m36(count, per) => "${count} стр. · по ${per}";

  static String m37(count) => "Торренты · ${count}";

  static String m38(tagNamespace) =>
      "${Intl.select(tagNamespace, {'reclass': 'reclass', 'language': 'language', 'parody': 'parody', 'character': 'character', 'group': 'group', 'artist': 'artist', 'male': 'male', 'female': 'female', 'mixed': 'mixed', 'cosplayer': 'cosplayer', 'other': 'other', 'temp': 'temp'})}";

  static String m39(version) => "Обновиться до ${version}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "KEEP_IT_SAFE": MessageLookupByLibrary.simpleMessage(
      "Никому не показывайте",
    ),
    "QR_code_block": MessageLookupByLibrary.simpleMessage(
      "Block images containing QR codes",
    ),
    "about": MessageLookupByLibrary.simpleMessage("О приложении"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "add_quick_search": MessageLookupByLibrary.simpleMessage("Добавить в БП"),
    "add_tag_placeholder": MessageLookupByLibrary.simpleMessage(
      "Введите новые теги, разделенные запятой",
    ),
    "add_tags": MessageLookupByLibrary.simpleMessage("Добавить теги"),
    "add_to_favorites": MessageLookupByLibrary.simpleMessage(
      "Добавить в избранное",
    ),
    "add_to_phash_block_list": MessageLookupByLibrary.simpleMessage(
      "Add to Perceptual Hash Block List",
    ),
    "advanced": MessageLookupByLibrary.simpleMessage("Дополнительно"),
    "aggregate": MessageLookupByLibrary.simpleMessage("Объединить"),
    "aggregate_groups": MessageLookupByLibrary.simpleMessage(
      "Объединить группы",
    ),
    "all_Favorites": MessageLookupByLibrary.simpleMessage("Все"),
    "all_comment": MessageLookupByLibrary.simpleMessage("Все комментарии"),
    "all_thumbnails": MessageLookupByLibrary.simpleMessage("Все превью"),
    "allow_media_scan": MessageLookupByLibrary.simpleMessage(
      "Разрешить видеть папку извне",
    ),
    "always": MessageLookupByLibrary.simpleMessage("Постоянно"),
    "app_title": MessageLookupByLibrary.simpleMessage("Eros-FE"),
    "appearance_and_layout": MessageLookupByLibrary.simpleMessage(
      "Вид и макет",
    ),
    "ask_me": MessageLookupByLibrary.simpleMessage("Спрашивать всегда"),
    "auth_biometricHint": MessageLookupByLibrary.simpleMessage(
      "Подтвердите личность",
    ),
    "auth_signInTitle": MessageLookupByLibrary.simpleMessage(
      "Требуется авторизация",
    ),
    "author": MessageLookupByLibrary.simpleMessage("Автор"),
    "autoLock": MessageLookupByLibrary.simpleMessage(
      "Автоматическая блокировка",
    ),
    "auto_scroll": MessageLookupByLibrary.simpleMessage("Автопрокрутка"),
    "auto_select_profile": MessageLookupByLibrary.simpleMessage(
      "Автоопределение профиля",
    ),
    "automatic": MessageLookupByLibrary.simpleMessage("Automatic"),
    "avatar": MessageLookupByLibrary.simpleMessage("Аватар"),
    "avatar_cf_verify_message": MessageLookupByLibrary.simpleMessage(
      "Форум защищён Cloudflare. Пройдите проверку во встроенном браузере, после чего загрузка будет повторена автоматически.",
    ),
    "avatar_cf_verify_title": MessageLookupByLibrary.simpleMessage(
      "Требуется проверка Cloudflare",
    ),
    "avatar_from_album": MessageLookupByLibrary.simpleMessage("Медиатека"),
    "avatar_from_file": MessageLookupByLibrary.simpleMessage("Файлы"),
    "avatar_from_url": MessageLookupByLibrary.simpleMessage("URL изображения"),
    "avatar_local_success": MessageLookupByLibrary.simpleMessage(
      "Аватар обновлён",
    ),
    "avatar_source": MessageLookupByLibrary.simpleMessage(
      "Выберите источник изображения",
    ),
    "avatar_target": MessageLookupByLibrary.simpleMessage(
      "Где использовать аватар?",
    ),
    "avatar_upload_success": MessageLookupByLibrary.simpleMessage(
      "Аватар загружен",
    ),
    "avatar_use_forum": MessageLookupByLibrary.simpleMessage(
      "Загрузить на форум EH",
    ),
    "avatar_use_local": MessageLookupByLibrary.simpleMessage(
      "Использовать только на устройстве",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Назад"),
    "back_to_top": MessageLookupByLibrary.simpleMessage("Наверх"),
    "block_rule": MessageLookupByLibrary.simpleMessage("Block Rule"),
    "block_rules": MessageLookupByLibrary.simpleMessage("Block Rules"),
    "blockers": MessageLookupByLibrary.simpleMessage("Blockers"),
    "blurring_cover_background": MessageLookupByLibrary.simpleMessage(
      "Размытие фона обложки",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "card_size": MessageLookupByLibrary.simpleMessage("Размер карточек"),
    "card_size_footer": MessageLookupByLibrary.simpleMessage(
      "Число столбцов считается по ширине панели со списком, поэтому меняется при смене экрана, повороте или перетаскивании разделителя. «Стандарт» совпадает с прежним автоматическим числом.",
    ),
    "card_size_large": MessageLookupByLibrary.simpleMessage("Крупные"),
    "card_size_larger": MessageLookupByLibrary.simpleMessage("Покрупнее"),
    "card_size_small": MessageLookupByLibrary.simpleMessage("Мелкие"),
    "card_size_smaller": MessageLookupByLibrary.simpleMessage("Поменьше"),
    "card_size_standard": MessageLookupByLibrary.simpleMessage("Стандарт"),
    "card_style": MessageLookupByLibrary.simpleMessage("Стиль карточек"),
    "card_style_immersive": MessageLookupByLibrary.simpleMessage("Погружение"),
    "card_style_immersive_detail": MessageLookupByLibrary.simpleMessage(
      "Только обложка, название и оценка поверх неё",
    ),
    "card_style_standard": MessageLookupByLibrary.simpleMessage("Обычный"),
    "card_style_standard_detail": MessageLookupByLibrary.simpleMessage(
      "Обложка, название, сведения и теги",
    ),
    "cf_verify_action": MessageLookupByLibrary.simpleMessage("Пройти"),
    "cf_verify_prompt": MessageLookupByLibrary.simpleMessage(
      "Запросы к форуму блокирует Cloudflare. Пройти проверку во встроенном браузере сейчас?",
    ),
    "cf_verify_required": MessageLookupByLibrary.simpleMessage(
      "Требуется проверка форума",
    ),
    "cf_verify_still_blocked": MessageLookupByLibrary.simpleMessage(
      "Проверка сохранена, но форум всё ещё блокирует запросы. Повторите позже или после смены сети.",
    ),
    "cf_verify_success": MessageLookupByLibrary.simpleMessage(
      "Проверка пройдена",
    ),
    "cf_verify_summary": MessageLookupByLibrary.simpleMessage(
      "Пройти проверку в приложении, если запросы к форуму блокируются",
    ),
    "cf_verify_title": MessageLookupByLibrary.simpleMessage(
      "Проверка Cloudflare",
    ),
    "change_to_favorites": MessageLookupByLibrary.simpleMessage(
      "Переместить в другое избранное",
    ),
    "chapter": MessageLookupByLibrary.simpleMessage("Глава"),
    "check_download_files_and_continue": MessageLookupByLibrary.simpleMessage(
      "Проверить файлы и продолжить",
    ),
    "check_for_update": MessageLookupByLibrary.simpleMessage(
      "Проверить на обновления",
    ),
    "choose_favcat": MessageLookupByLibrary.simpleMessage(
      "Выбрать папку избранного",
    ),
    "clear_cache": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "clear_filter": MessageLookupByLibrary.simpleMessage("Очистить"),
    "clear_search_history": MessageLookupByLibrary.simpleMessage(
      "Очистить историю поиска",
    ),
    "clipboard_detection": MessageLookupByLibrary.simpleMessage(
      "Анализ буфера обмена",
    ),
    "clipboard_detection_desc": MessageLookupByLibrary.simpleMessage(
      "Автоматически подцеплять ссылки из буфера обмена",
    ),
    "collapse": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "color_picker_primary": MessageLookupByLibrary.simpleMessage("основной"),
    "color_picker_wheel": MessageLookupByLibrary.simpleMessage("wheel"),
    "column_count": m0,
    "column_range": m1,
    "comment": MessageLookupByLibrary.simpleMessage("Comment"),
    "comment_count": m2,
    "commentator": MessageLookupByLibrary.simpleMessage("Commentator"),
    "concurrent_galleries": MessageLookupByLibrary.simpleMessage(
      "Макс. одновременных загрузок галерей",
    ),
    "continue_reading_page": m3,
    "copied_to_clipboard": MessageLookupByLibrary.simpleMessage(
      "Скопировано в буфер обмена",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copy_link": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copy_title": MessageLookupByLibrary.simpleMessage("Копировать название"),
    "current_site": m4,
    "current_version": MessageLookupByLibrary.simpleMessage("Текущая версия"),
    "custom_hosts": MessageLookupByLibrary.simpleMessage(
      "Пользовательские узлы",
    ),
    "custom_width": MessageLookupByLibrary.simpleMessage("Custom Width"),
    "dark": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "dark_mode_effect": MessageLookupByLibrary.simpleMessage("Вид тёмной темы"),
    "date_or_offset": MessageLookupByLibrary.simpleMessage("Date or Offset"),
    "default_avatar_style": MessageLookupByLibrary.simpleMessage(
      "Стиль аватара по умолчанию",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "delete_task": MessageLookupByLibrary.simpleMessage("Менеджер загрузок"),
    "delete_task_and_content": MessageLookupByLibrary.simpleMessage(
      "Удалить задание и файлы",
    ),
    "delete_task_only": MessageLookupByLibrary.simpleMessage(
      "Удалить только задание",
    ),
    "desktop_all_history": MessageLookupByLibrary.simpleMessage("Вся история"),
    "desktop_clear_history_detail": MessageLookupByLibrary.simpleMessage(
      "Удаляет историю просмотра и недавнее чтение на устройстве. Прогресс чтения и загрузки сохраняются.",
    ),
    "desktop_current_group": MessageLookupByLibrary.simpleMessage(
      "Текущая группа",
    ),
    "desktop_display_mode": MessageLookupByLibrary.simpleMessage(
      "Режим отображения",
    ),
    "desktop_follow_global": MessageLookupByLibrary.simpleMessage(
      "Использовать общий",
    ),
    "desktop_global_mode": MessageLookupByLibrary.simpleMessage(
      "Общий режим отображения",
    ),
    "desktop_global_mode_hint": MessageLookupByLibrary.simpleMessage(
      "Также применяется к спискам с общими настройками",
    ),
    "desktop_hide_sidebar": MessageLookupByLibrary.simpleMessage(
      "Скрыть боковую панель",
    ),
    "desktop_mode_sync_failed": MessageLookupByLibrary.simpleMessage(
      "Режим сохранён на устройстве. Не удалось синхронизировать: проверьте соединение.",
    ),
    "desktop_no_groups": MessageLookupByLibrary.simpleMessage("Нет групп"),
    "desktop_read_unavailable": MessageLookupByLibrary.simpleMessage(
      "Не удалось открыть произведение. Проверьте источник и повторите попытку.",
    ),
    "desktop_recent_empty": MessageLookupByLibrary.simpleMessage(
      "Начните чтение, и произведения появятся здесь.",
    ),
    "desktop_recent_reading": MessageLookupByLibrary.simpleMessage(
      "Недавно прочитанное",
    ),
    "desktop_refresh": MessageLookupByLibrary.simpleMessage(
      "Обновить текущий список",
    ),
    "desktop_refreshing": MessageLookupByLibrary.simpleMessage(
      "Обновление списка",
    ),
    "desktop_resize_panes": MessageLookupByLibrary.simpleMessage(
      "Изменить ширину списка и сведений",
    ),
    "desktop_show_sidebar": MessageLookupByLibrary.simpleMessage(
      "Показать боковую панель",
    ),
    "desktop_untitled": MessageLookupByLibrary.simpleMessage("Без названия"),
    "desktop_view_details": MessageLookupByLibrary.simpleMessage(
      "Показать сведения",
    ),
    "detail_ambient_background": MessageLookupByLibrary.simpleMessage(
      "Фон страницы галереи",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disabled": MessageLookupByLibrary.simpleMessage("Выключено"),
    "domain_fronting": MessageLookupByLibrary.simpleMessage("Фронтинг домена"),
    "donate": MessageLookupByLibrary.simpleMessage("Пожертвовать"),
    "done": MessageLookupByLibrary.simpleMessage("Готово"),
    "double_click_back": MessageLookupByLibrary.simpleMessage(
      "Нажмите еще раз, чтобы выйти",
    ),
    "double_page_model": MessageLookupByLibrary.simpleMessage(
      "Модель просмотра двух страниц",
    ),
    "download": MessageLookupByLibrary.simpleMessage("Загрузки"),
    "download_check_updates": MessageLookupByLibrary.simpleMessage(
      "Проверить обновления",
    ),
    "download_checking_updates": MessageLookupByLibrary.simpleMessage(
      "Проверка…",
    ),
    "download_files_unavailable": MessageLookupByLibrary.simpleMessage(
      "Файлы временно недоступны",
    ),
    "download_has_update_badge": MessageLookupByLibrary.simpleMessage(
      "Обновление",
    ),
    "download_incremental_reused_status": m5,
    "download_incremental_updating": MessageLookupByLibrary.simpleMessage(
      "Обновление",
    ),
    "download_location": MessageLookupByLibrary.simpleMessage(
      "Каталог загрузок",
    ),
    "download_ori_image": MessageLookupByLibrary.simpleMessage(
      "Загружать изображения исходного качества",
    ),
    "download_ori_image_summary": MessageLookupByLibrary.simpleMessage(
      "Это опасно! Вы можете получить ошибку 509",
    ),
    "download_update_all": MessageLookupByLibrary.simpleMessage("Обновить все"),
    "download_updates_checked_with_errors": m6,
    "download_updates_found": m7,
    "download_updates_none": MessageLookupByLibrary.simpleMessage(
      "Все загруженные галереи актуальны",
    ),
    "downloaded": MessageLookupByLibrary.simpleMessage("Скачано"),
    "downloading": MessageLookupByLibrary.simpleMessage("Скачивание"),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "edit_block_rule": MessageLookupByLibrary.simpleMessage("Edit Block Rule"),
    "edit_comment": MessageLookupByLibrary.simpleMessage(
      "Изменить комментарий",
    ),
    "eh": MessageLookupByLibrary.simpleMessage("E·H"),
    "ehentai_my_tags": MessageLookupByLibrary.simpleMessage("Мои теги"),
    "ehentai_settings": MessageLookupByLibrary.simpleMessage(
      "EHentai настройки",
    ),
    "enable": MessageLookupByLibrary.simpleMessage("Enable"),
    "english_title": MessageLookupByLibrary.simpleMessage("Название (EN)"),
    "enter_date_or_offset_or_gid": MessageLookupByLibrary.simpleMessage(
      "Enter date or offset or gid",
    ),
    "expand": MessageLookupByLibrary.simpleMessage("Показать"),
    "experimental_feature": MessageLookupByLibrary.simpleMessage(
      "Experimental feature",
    ),
    "export": MessageLookupByLibrary.simpleMessage("Экспортировать"),
    "export_app_data": MessageLookupByLibrary.simpleMessage("Export App Data"),
    "export_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "Export App Data To File",
    ),
    "favcat": MessageLookupByLibrary.simpleMessage("Избранное"),
    "favorite_note_hint": MessageLookupByLibrary.simpleMessage(
      "Заметка (необязательно)",
    ),
    "favorites_order": MessageLookupByLibrary.simpleMessage(
      "Упорядочить избранное",
    ),
    "favorites_order_Use_favorited": MessageLookupByLibrary.simpleMessage(
      "По дате добавления в избранное",
    ),
    "favorites_order_Use_posted": MessageLookupByLibrary.simpleMessage(
      "По дате обновления галереи",
    ),
    "file_size": MessageLookupByLibrary.simpleMessage("Размер"),
    "filter_by_uploader": MessageLookupByLibrary.simpleMessage(
      "Фильтр по загрузившему",
    ),
    "filter_comments_by_score": MessageLookupByLibrary.simpleMessage(
      "Filter Comments By Score",
    ),
    "filter_comments_by_score_summary": MessageLookupByLibrary.simpleMessage(
      "Comments below/equal to this score will be hidden",
    ),
    "fixed_height_of_list_items": MessageLookupByLibrary.simpleMessage(
      "Фиксированная высота элементов списка",
    ),
    "follow_system": MessageLookupByLibrary.simpleMessage("Как в системе"),
    "full_title": MessageLookupByLibrary.simpleMessage("Полное название"),
    "full_title_in_gallery": MessageLookupByLibrary.simpleMessage(
      "Показывать полное название",
    ),
    "full_title_in_gallery_subtitle": MessageLookupByLibrary.simpleMessage(
      "Второе название — отдельной строкой в списках и на странице галереи",
    ),
    "fullscreen": MessageLookupByLibrary.simpleMessage("На полный экран"),
    "galery_site": MessageLookupByLibrary.simpleMessage("Каталог галереи"),
    "gallery_comments": MessageLookupByLibrary.simpleMessage(
      "Комментарии галереи",
    ),
    "gallery_from_parent_hint": m8,
    "gallery_has_parent_hint": MessageLookupByLibrary.simpleMessage(
      "Есть родительская",
    ),
    "gallery_info": MessageLookupByLibrary.simpleMessage("Сведения о галерее"),
    "gallery_info_category": MessageLookupByLibrary.simpleMessage("Категория"),
    "gallery_info_cover_url": MessageLookupByLibrary.simpleMessage(
      "URL обложки",
    ),
    "gallery_info_expunged": MessageLookupByLibrary.simpleMessage("Удалено"),
    "gallery_info_favorite_status": MessageLookupByLibrary.simpleMessage(
      "Избранное",
    ),
    "gallery_info_gallery_url": MessageLookupByLibrary.simpleMessage(
      "URL галереи",
    ),
    "gallery_info_open_browser": MessageLookupByLibrary.simpleMessage(
      "Открыть в браузере",
    ),
    "gallery_info_open_browser_failed": MessageLookupByLibrary.simpleMessage(
      "Не удалось открыть ссылку в браузере",
    ),
    "gallery_info_posted": MessageLookupByLibrary.simpleMessage("Опубликовано"),
    "gallery_info_rating_votes": m9,
    "gallery_info_section_details": MessageLookupByLibrary.simpleMessage(
      "Сведения",
    ),
    "gallery_info_section_identifiers": MessageLookupByLibrary.simpleMessage(
      "Идентификаторы и ссылки",
    ),
    "gallery_info_section_titles": MessageLookupByLibrary.simpleMessage(
      "Названия",
    ),
    "gallery_info_visible": MessageLookupByLibrary.simpleMessage("Видимость"),
    "gallery_latest_version": MessageLookupByLibrary.simpleMessage("Новейшая"),
    "gallery_lineage": MessageLookupByLibrary.simpleMessage("Версии галереи"),
    "gallery_lineage_tap_hint": MessageLookupByLibrary.simpleMessage(
      "Нажмите для перехода · Удерживайте для копирования",
    ),
    "gallery_metadata": MessageLookupByLibrary.simpleMessage("Метаданные"),
    "gallery_metadata_copy_hint": MessageLookupByLibrary.simpleMessage(
      "Нажмите для копирования",
    ),
    "gallery_newer_version_count": m10,
    "gallery_newer_version_single": MessageLookupByLibrary.simpleMessage(
      "Доступна новая версия",
    ),
    "gallery_newer_versions": MessageLookupByLibrary.simpleMessage(
      "Новые версии",
    ),
    "gallery_open_latest_version": MessageLookupByLibrary.simpleMessage(
      "Открыть последнюю версию",
    ),
    "gallery_open_parent": MessageLookupByLibrary.simpleMessage(
      "Открыть родительскую галерею",
    ),
    "gallery_parent": MessageLookupByLibrary.simpleMessage("Родительская"),
    "gallery_parent_none": MessageLookupByLibrary.simpleMessage("Нет"),
    "gallery_parent_unavailable": MessageLookupByLibrary.simpleMessage(
      "Недоступно",
    ),
    "gallery_stats": MessageLookupByLibrary.simpleMessage("Статистика галереи"),
    "gallery_stats_all_time": MessageLookupByLibrary.simpleMessage(
      "За всё время",
    ),
    "gallery_stats_collapse": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "gallery_stats_current_version": m11,
    "gallery_stats_daily": MessageLookupByLibrary.simpleMessage("По дням"),
    "gallery_stats_daily_avg": MessageLookupByLibrary.simpleMessage("В день"),
    "gallery_stats_empty_body": MessageLookupByLibrary.simpleMessage(
      "Доступ к stats.php на E-Hentai зависит от прав аккаунта (донор/загрузчик) и статуса галереи.",
    ),
    "gallery_stats_empty_title": MessageLookupByLibrary.simpleMessage(
      "Статистика недоступна",
    ),
    "gallery_stats_expand_action": MessageLookupByLibrary.simpleMessage(
      "Загрузить статистику",
    ),
    "gallery_stats_expand_hint": MessageLookupByLibrary.simpleMessage(
      "Загрузка stats.php по запросу (зависит от прав аккаунта)",
    ),
    "gallery_stats_fav_rate": MessageLookupByLibrary.simpleMessage("В избр."),
    "gallery_stats_hits": MessageLookupByLibrary.simpleMessage("Хиты"),
    "gallery_stats_load_failed": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить статистику",
    ),
    "gallery_stats_loading": MessageLookupByLibrary.simpleMessage(
      "Загрузка статистики…",
    ),
    "gallery_stats_login_required": MessageLookupByLibrary.simpleMessage(
      "Войдите в E-Hentai, чтобы посмотреть статистику",
    ),
    "gallery_stats_monthly": MessageLookupByLibrary.simpleMessage("По месяцам"),
    "gallery_stats_no_rankings": MessageLookupByLibrary.simpleMessage(
      "Галерея не входит в топы",
    ),
    "gallery_stats_no_series_data": MessageLookupByLibrary.simpleMessage(
      "Нет данных за этот период",
    ),
    "gallery_stats_open_web": MessageLookupByLibrary.simpleMessage(
      "Открыть stats.php",
    ),
    "gallery_stats_past_month": MessageLookupByLibrary.simpleMessage(
      "За месяц",
    ),
    "gallery_stats_past_year": MessageLookupByLibrary.simpleMessage("За год"),
    "gallery_stats_peak": m12,
    "gallery_stats_period_avg": m13,
    "gallery_stats_period_share": m14,
    "gallery_stats_period_total": m15,
    "gallery_stats_ranking": MessageLookupByLibrary.simpleMessage("Рейтинг"),
    "gallery_stats_refresh": MessageLookupByLibrary.simpleMessage(
      "Обновить статистику",
    ),
    "gallery_stats_retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "gallery_stats_score": m16,
    "gallery_stats_total_visits": MessageLookupByLibrary.simpleMessage(
      "Просмотры",
    ),
    "gallery_stats_unranked": MessageLookupByLibrary.simpleMessage("Вне топа"),
    "gallery_stats_visits": MessageLookupByLibrary.simpleMessage("Визиты"),
    "gallery_stats_yearly": MessageLookupByLibrary.simpleMessage("По годам"),
    "gallery_stats_yesterday": MessageLookupByLibrary.simpleMessage("Вчера"),
    "gallery_updatable_hint": MessageLookupByLibrary.simpleMessage(
      "Можно обновить",
    ),
    "gallery_updated_on": m17,
    "gallery_view_lineage_hint": MessageLookupByLibrary.simpleMessage("Версии"),
    "glass_effect": MessageLookupByLibrary.simpleMessage("Эффект стекла"),
    "glass_material": MessageLookupByLibrary.simpleMessage("Материал стекла"),
    "glass_material_frosted": MessageLookupByLibrary.simpleMessage(
      "Матовое стекло",
    ),
    "glass_material_frosted_detail": MessageLookupByLibrary.simpleMessage(
      "Мягкое размытие, выше производительность",
    ),
    "glass_material_liquid": MessageLookupByLibrary.simpleMessage(
      "Жидкое стекло",
    ),
    "glass_material_liquid_detail": MessageLookupByLibrary.simpleMessage(
      "Преломление и блики, больше расход энергии",
    ),
    "glass_system_bar_note": MessageLookupByLibrary.simpleMessage(
      "Вертикальные панели вкладок, которые рисует система (например, боковая панель на внешнем экране iPhone Duo), всегда из жидкого стекла.",
    ),
    "global_setting": MessageLookupByLibrary.simpleMessage("Как в настройках"),
    "gray_black": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "group": MessageLookupByLibrary.simpleMessage("Категории"),
    "groupName": MessageLookupByLibrary.simpleMessage("Название категории"),
    "groupType": MessageLookupByLibrary.simpleMessage("Тип категории"),
    "group_management": MessageLookupByLibrary.simpleMessage(
      "Управление группами",
    ),
    "hide": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "hide_gallery_thumbnails": MessageLookupByLibrary.simpleMessage(
      "Hide Gallery Thumbnails",
    ),
    "hide_thumbnails": MessageLookupByLibrary.simpleMessage("Hide Thumbnails"),
    "hide_top_bar_on_scroll": MessageLookupByLibrary.simpleMessage(
      "Hide top bar on scroll",
    ),
    "high_resolution_images_limited": MessageLookupByLibrary.simpleMessage(
      "High Resolution Images Limited",
    ),
    "horizontal_thumbnails": MessageLookupByLibrary.simpleMessage(
      "Horizontal Thumbnails",
    ),
    "host": MessageLookupByLibrary.simpleMessage("Узел"),
    "hours": MessageLookupByLibrary.simpleMessage("час(ов)"),
    "image_block": MessageLookupByLibrary.simpleMessage("Image Block"),
    "image_download_type": MessageLookupByLibrary.simpleMessage("Тип загрузки"),
    "image_limits": MessageLookupByLibrary.simpleMessage(
      "Ограничения изображения",
    ),
    "image_save_busy": MessageLookupByLibrary.simpleMessage(
      "Изображение уже сохраняется.",
    ),
    "image_save_download": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить изображение. Повторите попытку.",
    ),
    "image_save_invalid": MessageLookupByLibrary.simpleMessage(
      "Файл изображения отсутствует, повреждён или загружен не полностью.",
    ),
    "image_save_permission": MessageLookupByLibrary.simpleMessage(
      "Нет разрешения на добавление фотографий. Разрешите его в настройках системы. При использовании LiveContainer проверьте его доступ к фотографиям.",
    ),
    "image_save_unsupported": MessageLookupByLibrary.simpleMessage(
      "Фотоальбом не поддерживает этот формат изображения.",
    ),
    "image_save_write": MessageLookupByLibrary.simpleMessage(
      "Не удалось записать изображение в фотоальбом. Повторите попытку.",
    ),
    "import_app_data": MessageLookupByLibrary.simpleMessage("Import App Data"),
    "import_app_data_summary": MessageLookupByLibrary.simpleMessage(
      "Import App Data From Backup File, need restart app",
    ),
    "import_export": MessageLookupByLibrary.simpleMessage("Импорт и экспорт"),
    "incremental_update_added": MessageLookupByLibrary.simpleMessage(
      "Добавлено",
    ),
    "incremental_update_all_reused": MessageLookupByLibrary.simpleMessage(
      "Все страницы использованы локально",
    ),
    "incremental_update_applying": MessageLookupByLibrary.simpleMessage(
      "Применение обновления…",
    ),
    "incremental_update_compare_failed": MessageLookupByLibrary.simpleMessage(
      "Не удалось проанализировать новую версию",
    ),
    "incremental_update_comparing": MessageLookupByLibrary.simpleMessage(
      "Анализ отличий страниц…",
    ),
    "incremental_update_completed_locally": m18,
    "incremental_update_entry": MessageLookupByLibrary.simpleMessage(
      "Инкрементально обновить загрузку",
    ),
    "incremental_update_local_tag": MessageLookupByLibrary.simpleMessage(
      "Локально",
    ),
    "incremental_update_mode_inplace": MessageLookupByLibrary.simpleMessage(
      "Обновить на месте и сохранить прогресс",
    ),
    "incremental_update_mode_inplace_desc": m19,
    "incremental_update_mode_new": MessageLookupByLibrary.simpleMessage(
      "Скачать как новую задачу (сохранить старую)",
    ),
    "incremental_update_mode_new_desc": m20,
    "incremental_update_mode_title": MessageLookupByLibrary.simpleMessage(
      "Способ обновления",
    ),
    "incremental_update_newer_tag": MessageLookupByLibrary.simpleMessage(
      "Новая",
    ),
    "incremental_update_only_download": m21,
    "incremental_update_recommended": MessageLookupByLibrary.simpleMessage(
      "Рекомендуется",
    ),
    "incremental_update_replaced": MessageLookupByLibrary.simpleMessage(
      "Заменено",
    ),
    "incremental_update_reused": MessageLookupByLibrary.simpleMessage(
      "Повторно",
    ),
    "incremental_update_saf_inplace_unsupported":
        MessageLookupByLibrary.simpleMessage(
          "Хранилище SAF не поддерживает локальное копирование и обновление на месте; все страницы будут загружены как новая задача.",
        ),
    "incremental_update_start_inplace": m22,
    "incremental_update_start_new": m23,
    "incremental_update_start_reuse_only": MessageLookupByLibrary.simpleMessage(
      "Завершить локально (0 стр. к загрузке)",
    ),
    "incremental_update_start_saf_full": m24,
    "incremental_update_started": m25,
    "incremental_update_subtitle": MessageLookupByLibrary.simpleMessage(
      "Повторное использование неизменённых страниц",
    ),
    "incremental_update_target_version": MessageLookupByLibrary.simpleMessage(
      "Целевая версия",
    ),
    "incremental_update_title": MessageLookupByLibrary.simpleMessage(
      "Инкрементальное обновление",
    ),
    "incremental_update_version_compare": MessageLookupByLibrary.simpleMessage(
      "Сравнение версий",
    ),
    "incremental_update_view_newer": MessageLookupByLibrary.simpleMessage(
      "Открыть новую галерею",
    ),
    "inner_display": MessageLookupByLibrary.simpleMessage("Внутренний экран"),
    "input_empty": MessageLookupByLibrary.simpleMessage("Буфер обмена пуст"),
    "input_error": MessageLookupByLibrary.simpleMessage("Ошибка ввода"),
    "instantly": MessageLookupByLibrary.simpleMessage("Сразу"),
    "japanese_title": MessageLookupByLibrary.simpleMessage("Название (JP)"),
    "japanese_title_in_gallery": MessageLookupByLibrary.simpleMessage(
      "Japanese Title in Gallery",
    ),
    "japanese_title_in_gallery_summary": MessageLookupByLibrary.simpleMessage(
      "Японское название — только на странице галереи",
    ),
    "jump_next": MessageLookupByLibrary.simpleMessage("Next"),
    "jump_or_seek": MessageLookupByLibrary.simpleMessage("Jump or Seek"),
    "jump_prev": MessageLookupByLibrary.simpleMessage("Prev"),
    "jump_to_page": MessageLookupByLibrary.simpleMessage("Перейти на страницу"),
    "landscape": MessageLookupByLibrary.simpleMessage("Альбомная"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "last_favorites": MessageLookupByLibrary.simpleMessage(
      "Последнее использованное избранное, долгий тап чтобы выбрать вручную",
    ),
    "latest_version": MessageLookupByLibrary.simpleMessage("Последняя версия"),
    "layout": MessageLookupByLibrary.simpleMessage("Внешний вид"),
    "left_to_right": MessageLookupByLibrary.simpleMessage("Слева направо"),
    "license": MessageLookupByLibrary.simpleMessage("Лицензии"),
    "light": MessageLookupByLibrary.simpleMessage("Светлая"),
    "link_redirect": MessageLookupByLibrary.simpleMessage(
      "Перенаправление ссылок",
    ),
    "link_redirect_summary": MessageLookupByLibrary.simpleMessage(
      "Перенаправление ссылок на галереи на выбранные сайты",
    ),
    "liquid_glass_description": MessageLookupByLibrary.simpleMessage(
      "Стекло для панелей навигации, панелей вкладок, кнопок и меню. Матовое стекло расходует меньше энергии и прокручивается плавнее.",
    ),
    "liquid_glass_inline": MessageLookupByLibrary.simpleMessage("Одна строка"),
    "liquid_glass_inline_detail": MessageLookupByLibrary.simpleMessage(
      "Действия и категории в одной строке",
    ),
    "liquid_glass_top_layout": MessageLookupByLibrary.simpleMessage(
      "Расположение категорий",
    ),
    "liquid_glass_two_row": MessageLookupByLibrary.simpleMessage(
      "Две строки (по умолчанию)",
    ),
    "liquid_glass_two_row_detail": MessageLookupByLibrary.simpleMessage(
      "Действия и категории в отдельных строках",
    ),
    "list_load_more_fail": MessageLookupByLibrary.simpleMessage(
      "Загрузка не удалась... нажмите, чтобы попробовать еще раз",
    ),
    "list_mode": MessageLookupByLibrary.simpleMessage("Отображение"),
    "listmode_grid": MessageLookupByLibrary.simpleMessage("Сетка"),
    "listmode_grid_tags": MessageLookupByLibrary.simpleMessage("Сетка - Теги"),
    "listmode_medium": MessageLookupByLibrary.simpleMessage("Список - Средний"),
    "listmode_small": MessageLookupByLibrary.simpleMessage(
      "Список - Компактный",
    ),
    "listmode_waterfall": MessageLookupByLibrary.simpleMessage("Водопад"),
    "listmode_waterfall_large": MessageLookupByLibrary.simpleMessage(
      "Водопад - Крупный",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "local_favorite": MessageLookupByLibrary.simpleMessage(
      "Локальное Избранное",
    ),
    "login": MessageLookupByLibrary.simpleMessage("Войти"),
    "login_web": MessageLookupByLibrary.simpleMessage("Войти через браузер"),
    "max_history": MessageLookupByLibrary.simpleMessage("Maximum history"),
    "min": MessageLookupByLibrary.simpleMessage("минут"),
    "model": m26,
    "more_actions": MessageLookupByLibrary.simpleMessage("Ещё"),
    "more_thumbnails": MessageLookupByLibrary.simpleMessage("Показать ещё"),
    "multi_download": MessageLookupByLibrary.simpleMessage(
      "Многопоточная загрузка",
    ),
    "mytags_on_website": MessageLookupByLibrary.simpleMessage(
      "Мои теги на сайте",
    ),
    "native_http_client_adapter": MessageLookupByLibrary.simpleMessage(
      "Native HTTP Client Adapter",
    ),
    "never": MessageLookupByLibrary.simpleMessage("Никогда"),
    "newGroup": MessageLookupByLibrary.simpleMessage("Новая категория"),
    "newText": MessageLookupByLibrary.simpleMessage("Новый тег"),
    "new_comment": MessageLookupByLibrary.simpleMessage("Новый комментарий"),
    "no": MessageLookupByLibrary.simpleMessage("Нет"),
    "no_limit": MessageLookupByLibrary.simpleMessage("Без лимита"),
    "no_more_thumbnails": MessageLookupByLibrary.simpleMessage("Конец списка"),
    "notFav": MessageLookupByLibrary.simpleMessage("Добавить в избранное"),
    "not_login": MessageLookupByLibrary.simpleMessage("Not Login"),
    "off": MessageLookupByLibrary.simpleMessage("Выключены"),
    "ok": MessageLookupByLibrary.simpleMessage("ОК"),
    "on": MessageLookupByLibrary.simpleMessage("Включены"),
    "one_step_favorite": MessageLookupByLibrary.simpleMessage(
      "One Step Favorite",
    ),
    "one_step_favorite_desc": MessageLookupByLibrary.simpleMessage(
      "Quickly add gallery to favorite, short press to save to the last selected favorite, long press to display the favorite dialog.",
    ),
    "open_supported_links": MessageLookupByLibrary.simpleMessage(
      "Открывать поддерживаемые ссылки",
    ),
    "open_supported_links_summary": MessageLookupByLibrary.simpleMessage(
      "Начиная с Android 12, приложения могут обрабатывать ссылки только если они одобрены. В противном случае ссылки будут обработаны через браузер по умолчанию. Вы можете вручную одобрить ссылки здесь",
    ),
    "open_with_other_apps": MessageLookupByLibrary.simpleMessage(
      "Открыть в другом приложении",
    ),
    "orientation_auto": MessageLookupByLibrary.simpleMessage("Свободная"),
    "orientation_landscapeLeft": MessageLookupByLibrary.simpleMessage(
      "Альбомная-слева",
    ),
    "orientation_landscapeRight": MessageLookupByLibrary.simpleMessage(
      "Альбомная-справа",
    ),
    "orientation_portraitUp": MessageLookupByLibrary.simpleMessage(
      "Портретная",
    ),
    "orientation_system": MessageLookupByLibrary.simpleMessage("Как в системе"),
    "original_image": MessageLookupByLibrary.simpleMessage("Оригинальное"),
    "outer_display": MessageLookupByLibrary.simpleMessage("Внешний экран"),
    "p_Archiver": MessageLookupByLibrary.simpleMessage("Архиватор"),
    "p_Download": MessageLookupByLibrary.simpleMessage("Скачать"),
    "p_Rate": MessageLookupByLibrary.simpleMessage("Оценить"),
    "p_Similar": MessageLookupByLibrary.simpleMessage("Похожие"),
    "p_Torrent": MessageLookupByLibrary.simpleMessage("Торрент"),
    "page_count": m27,
    "page_range": MessageLookupByLibrary.simpleMessage("Диапазон страниц"),
    "page_range_error": MessageLookupByLibrary.simpleMessage(
      "Ошибка в диапазоне страниц",
    ),
    "page_view_type": MessageLookupByLibrary.simpleMessage("Page View Type"),
    "passwd": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paused": MessageLookupByLibrary.simpleMessage("На паузе"),
    "phash_block_list": MessageLookupByLibrary.simpleMessage(
      "Perceptual Hash Block List",
    ),
    "phash_check": MessageLookupByLibrary.simpleMessage(
      "Perceptual Hash Check (Block similar images)",
    ),
    "pls_i_passwd": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите пароль",
    ),
    "pls_i_username": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите логин",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portrait": MessageLookupByLibrary.simpleMessage("Портретная"),
    "preload_image": MessageLookupByLibrary.simpleMessage(
      "Предварительная загрузка изображений",
    ),
    "processing": MessageLookupByLibrary.simpleMessage("В процессе"),
    "proxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxy_type": MessageLookupByLibrary.simpleMessage("Тип прокси"),
    "pure_black": MessageLookupByLibrary.simpleMessage("Чёрная"),
    "quick_search": MessageLookupByLibrary.simpleMessage("Быстрый поиск"),
    "ranking_period": MessageLookupByLibrary.simpleMessage("Период рейтинга"),
    "read": MessageLookupByLibrary.simpleMessage("Чтение"),
    "read_from_clipboard": MessageLookupByLibrary.simpleMessage(
      "Вставить из буфера обмена",
    ),
    "read_setting": MessageLookupByLibrary.simpleMessage("Настройки читалки"),
    "read_view_compatible_mode": MessageLookupByLibrary.simpleMessage(
      "Compatible Mode",
    ),
    "reader_auto_read": MessageLookupByLibrary.simpleMessage("Автолистание"),
    "reader_auto_read_interval": MessageLookupByLibrary.simpleMessage(
      "Интервал",
    ),
    "reader_custom_interval": MessageLookupByLibrary.simpleMessage("Другой…"),
    "reader_double_even_left": MessageLookupByLibrary.simpleMessage(
      "Две страницы (чётная слева)",
    ),
    "reader_double_odd_left": MessageLookupByLibrary.simpleMessage(
      "Две страницы (нечётная слева)",
    ),
    "reader_double_page": MessageLookupByLibrary.simpleMessage("Разворот"),
    "reader_fill_footer": MessageLookupByLibrary.simpleMessage(
      "Скрывает строку состояния при чтении в этой ориентации, изображения занимают весь экран без безопасной зоны",
    ),
    "reader_fill_landscape": MessageLookupByLibrary.simpleMessage(
      "Весь экран в альбомной ориентации",
    ),
    "reader_fill_portrait": MessageLookupByLibrary.simpleMessage(
      "Весь экран в портретной ориентации",
    ),
    "reader_interval_seconds": m28,
    "reader_next_page": MessageLookupByLibrary.simpleMessage(
      "Следующая страница",
    ),
    "reader_page_layout": MessageLookupByLibrary.simpleMessage(
      "Макет страницы",
    ),
    "reader_page_of": m29,
    "reader_previous_page": MessageLookupByLibrary.simpleMessage(
      "Предыдущая страница",
    ),
    "reader_single_page": MessageLookupByLibrary.simpleMessage("Одна страница"),
    "reader_surface_standard": MessageLookupByLibrary.simpleMessage(
      "Стандартный",
    ),
    "reader_surface_tabletop": MessageLookupByLibrary.simpleMessage(
      "Настольный режим",
    ),
    "reader_turn_page": MessageLookupByLibrary.simpleMessage("Листать"),
    "reader_vertical": MessageLookupByLibrary.simpleMessage("Вертикально"),
    "reading_direction": MessageLookupByLibrary.simpleMessage("Режим чтения"),
    "rebuild_tasks_data": MessageLookupByLibrary.simpleMessage(
      "Пересобрать задания",
    ),
    "redirect_thumb_link": MessageLookupByLibrary.simpleMessage(
      "Перенаправление адреса миниатюры",
    ),
    "redirect_thumb_link_summary": MessageLookupByLibrary.simpleMessage(
      "Перенаправление адреса миниатюры на ehgt.org",
    ),
    "redownload": MessageLookupByLibrary.simpleMessage("Скачать заново"),
    "refresh_igneous": MessageLookupByLibrary.simpleMessage("Refresh Igneous"),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "regex_format_error": MessageLookupByLibrary.simpleMessage(
      "Regex format error",
    ),
    "reload": MessageLookupByLibrary.simpleMessage("Обновить"),
    "reload_image": MessageLookupByLibrary.simpleMessage("Загрузить заново"),
    "remove_all": MessageLookupByLibrary.simpleMessage("Удалить все"),
    "remove_from_favorites": MessageLookupByLibrary.simpleMessage(
      "Удалить из избранного",
    ),
    "reply_to_comment": MessageLookupByLibrary.simpleMessage("Ответить"),
    "resample_image": MessageLookupByLibrary.simpleMessage("Сжатое"),
    "reset_cost": MessageLookupByLibrary.simpleMessage("Сбросить стоимость"),
    "restore_tasks_data": MessageLookupByLibrary.simpleMessage(
      "Возобновить задания",
    ),
    "right_to_left": MessageLookupByLibrary.simpleMessage("Справа налево"),
    "s_Advanced_Options": MessageLookupByLibrary.simpleMessage(
      "Дополнительные параметры",
    ),
    "s_Between": MessageLookupByLibrary.simpleMessage("Среди"),
    "s_Disable_default_filters": MessageLookupByLibrary.simpleMessage(
      "Отключить стандартные фильтры",
    ),
    "s_Minimum_Rating": MessageLookupByLibrary.simpleMessage(
      "Минимальная оценка",
    ),
    "s_Only_Show_Galleries_With_Torrents": MessageLookupByLibrary.simpleMessage(
      "Показывать только галереи с торрентами",
    ),
    "s_Search_Downvoted_Tags": MessageLookupByLibrary.simpleMessage(
      "Искать с нежеланными тегами",
    ),
    "s_Search_Fav_Name": MessageLookupByLibrary.simpleMessage(
      "Искать в названии",
    ),
    "s_Search_Fav_Note": MessageLookupByLibrary.simpleMessage(
      "Искать в заметках",
    ),
    "s_Search_Fav_Tags": MessageLookupByLibrary.simpleMessage("Искать в тегах"),
    "s_Search_Gallery_Description": MessageLookupByLibrary.simpleMessage(
      "Поиск в описании галерей",
    ),
    "s_Search_Gallery_Name": MessageLookupByLibrary.simpleMessage(
      "Поиск в названии галерей",
    ),
    "s_Search_Gallery_Tags": MessageLookupByLibrary.simpleMessage(
      "Поиск в тегах галерей",
    ),
    "s_Search_Low_Power_Tags": MessageLookupByLibrary.simpleMessage(
      "Искать с малым количеством тегов",
    ),
    "s_Search_Torrent_Filenames": MessageLookupByLibrary.simpleMessage(
      "Искать в названиях торрентов",
    ),
    "s_Show_Expunged_Galleries": MessageLookupByLibrary.simpleMessage(
      "Показывать скрытые галереи",
    ),
    "s_and": MessageLookupByLibrary.simpleMessage("и"),
    "s_pages": MessageLookupByLibrary.simpleMessage("страницы"),
    "s_stars": m30,
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "save_current_image": MessageLookupByLibrary.simpleMessage(
      "Сохранить текущее изображение",
    ),
    "save_into_album": MessageLookupByLibrary.simpleMessage(
      "Сохранить в галерею",
    ),
    "save_original_image": MessageLookupByLibrary.simpleMessage(
      "Сохранить оригинал",
    ),
    "saved_successfully": MessageLookupByLibrary.simpleMessage(
      "Успешно сохранено",
    ),
    "screen_orientation": MessageLookupByLibrary.simpleMessage(
      "Ориентация экрана",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "searchTexts": MessageLookupByLibrary.simpleMessage("Поиск тегов"),
    "search_by_image": MessageLookupByLibrary.simpleMessage(
      "Поиск по изображению",
    ),
    "search_history": MessageLookupByLibrary.simpleMessage("История поиска"),
    "search_title": MessageLookupByLibrary.simpleMessage("Искать по названию"),
    "search_type": MessageLookupByLibrary.simpleMessage("Искать тип"),
    "second": MessageLookupByLibrary.simpleMessage("секунд"),
    "security": MessageLookupByLibrary.simpleMessage("Безопасность"),
    "security_blurredInRecentTasks": MessageLookupByLibrary.simpleMessage(
      "Защита экрана приложения",
    ),
    "see_all": MessageLookupByLibrary.simpleMessage("Все"),
    "setting_group_browse": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "setting_group_content": MessageLookupByLibrary.simpleMessage("Контент"),
    "setting_group_system": MessageLookupByLibrary.simpleMessage("Система"),
    "setting_on_website": MessageLookupByLibrary.simpleMessage(
      "Настройки на сайте",
    ),
    "setting_site": MessageLookupByLibrary.simpleMessage("Сайт"),
    "share": MessageLookupByLibrary.simpleMessage("Поделиться"),
    "share_image": MessageLookupByLibrary.simpleMessage(
      "Поделиться изображением",
    ),
    "show_comment_avatar": MessageLookupByLibrary.simpleMessage(
      "Показать аватар комментатора",
    ),
    "show_comments": MessageLookupByLibrary.simpleMessage("Show Comments"),
    "show_english_title": MessageLookupByLibrary.simpleMessage(
      "Показать английское",
    ),
    "show_filter": MessageLookupByLibrary.simpleMessage("Показать фильтр"),
    "show_gallery_tags": MessageLookupByLibrary.simpleMessage(
      "Show Gallery Tags",
    ),
    "show_japanese_title": MessageLookupByLibrary.simpleMessage(
      "Показать японское",
    ),
    "show_jpn_title": MessageLookupByLibrary.simpleMessage(
      "Показывать названия на японском",
    ),
    "show_only_uploader_comment": MessageLookupByLibrary.simpleMessage(
      "Show Only Uploader Comment",
    ),
    "show_page_interval": MessageLookupByLibrary.simpleMessage(
      "Показывать интервал между страницами",
    ),
    "sidebar_library": MessageLookupByLibrary.simpleMessage("Библиотека"),
    "skip": MessageLookupByLibrary.simpleMessage("Пропустить"),
    "slide_out_page": MessageLookupByLibrary.simpleMessage("Slide Out Page"),
    "sp_add_quick_search": MessageLookupByLibrary.simpleMessage(
      "В быстрые запросы",
    ),
    "sp_add_tag": m31,
    "sp_all": MessageLookupByLibrary.simpleMessage("Все"),
    "sp_all_favcats": MessageLookupByLibrary.simpleMessage("Всё избранное"),
    "sp_archive_original": MessageLookupByLibrary.simpleMessage(
      "Оригинальный архив",
    ),
    "sp_archive_resample": MessageLookupByLibrary.simpleMessage("Сжатый архив"),
    "sp_archiver_error": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить",
    ),
    "sp_archiver_hath": MessageLookupByLibrary.simpleMessage(
      "Загрузка через H@H",
    ),
    "sp_archiver_loading": MessageLookupByLibrary.simpleMessage(
      "Загрузка сведений об архиве",
    ),
    "sp_archiver_local": MessageLookupByLibrary.simpleMessage(
      "Скачать на устройство",
    ),
    "sp_category": MessageLookupByLibrary.simpleMessage("Категории"),
    "sp_change_image": MessageLookupByLibrary.simpleMessage("Сменить"),
    "sp_clear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "sp_clear_text": MessageLookupByLibrary.simpleMessage("Очистить текст"),
    "sp_date": MessageLookupByLibrary.simpleMessage("Дата"),
    "sp_done": MessageLookupByLibrary.simpleMessage("Готово"),
    "sp_favcat": MessageLookupByLibrary.simpleMessage("Избранное"),
    "sp_filter": MessageLookupByLibrary.simpleMessage("Фильтр"),
    "sp_first_page": MessageLookupByLibrary.simpleMessage("Первая"),
    "sp_free": MessageLookupByLibrary.simpleMessage("Бесплатно"),
    "sp_go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "sp_hide_keyboard": MessageLookupByLibrary.simpleMessage(
      "Скрыть клавиатуру",
    ),
    "sp_image_search": MessageLookupByLibrary.simpleMessage(
      "Поиск по картинке",
    ),
    "sp_image_search_options": MessageLookupByLibrary.simpleMessage(
      "Параметры поиска",
    ),
    "sp_include_expunged": MessageLookupByLibrary.simpleMessage(
      "Включая удалённые",
    ),
    "sp_invert_selection": MessageLookupByLibrary.simpleMessage(
      "Инвертировать",
    ),
    "sp_last_page": MessageLookupByLibrary.simpleMessage("Последняя"),
    "sp_middle_page": MessageLookupByLibrary.simpleMessage("Середина"),
    "sp_more": MessageLookupByLibrary.simpleMessage("Ещё"),
    "sp_only_covers": MessageLookupByLibrary.simpleMessage("Только обложки"),
    "sp_open_link": MessageLookupByLibrary.simpleMessage("Открыть галерею"),
    "sp_optional": MessageLookupByLibrary.simpleMessage("Необязательно"),
    "sp_original": MessageLookupByLibrary.simpleMessage("Оригинал"),
    "sp_page_first": MessageLookupByLibrary.simpleMessage("Первая"),
    "sp_page_last": MessageLookupByLibrary.simpleMessage("Последняя"),
    "sp_page_next": MessageLookupByLibrary.simpleMessage("Вперёд"),
    "sp_page_prev": MessageLookupByLibrary.simpleMessage("Назад"),
    "sp_page_total": m32,
    "sp_pick_image": MessageLookupByLibrary.simpleMessage(
      "Нажмите, чтобы выбрать изображение",
    ),
    "sp_quick_search_list": MessageLookupByLibrary.simpleMessage(
      "Быстрые запросы",
    ),
    "sp_rate_submit": MessageLookupByLibrary.simpleMessage("Оценить"),
    "sp_rating_summary": m33,
    "sp_recent_searches": MessageLookupByLibrary.simpleMessage("Недавние"),
    "sp_refresh": MessageLookupByLibrary.simpleMessage("Обновить"),
    "sp_reset": MessageLookupByLibrary.simpleMessage("Сбросить"),
    "sp_retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "sp_search_for": m34,
    "sp_search_placeholder": MessageLookupByLibrary.simpleMessage(
      "Название, теги или ссылка",
    ),
    "sp_seek_hint": MessageLookupByLibrary.simpleMessage(
      "Дата 2024-05-01 · смещение 3d 2w 1y · или GID",
    ),
    "sp_seek_newer": MessageLookupByLibrary.simpleMessage("Новее"),
    "sp_seek_older": MessageLookupByLibrary.simpleMessage("Старее"),
    "sp_seek_section": MessageLookupByLibrary.simpleMessage(
      "Перейти по дате или GID",
    ),
    "sp_select_all": MessageLookupByLibrary.simpleMessage("Все"),
    "sp_show_date_picker": MessageLookupByLibrary.simpleMessage("Выбрать дату"),
    "sp_similar_scan": MessageLookupByLibrary.simpleMessage("Поиск похожих"),
    "sp_start_search": MessageLookupByLibrary.simpleMessage("Искать"),
    "sp_suggestions": MessageLookupByLibrary.simpleMessage("Подсказки"),
    "sp_tags_added": m35,
    "sp_tags_example": MessageLookupByLibrary.simpleMessage(
      "Напр. female:glasses, full color",
    ),
    "sp_thumbs_jump": MessageLookupByLibrary.simpleMessage("К странице превью"),
    "sp_thumbs_per_page": m36,
    "sp_torrent_completed": MessageLookupByLibrary.simpleMessage("Готово"),
    "sp_torrent_download": MessageLookupByLibrary.simpleMessage(
      "Скачать торрент",
    ),
    "sp_torrent_empty": MessageLookupByLibrary.simpleMessage(
      "Нет доступных торрентов",
    ),
    "sp_torrent_magnet": MessageLookupByLibrary.simpleMessage(
      "Поделиться magnet",
    ),
    "sp_torrent_peers": MessageLookupByLibrary.simpleMessage("Пиры"),
    "sp_torrent_seeds": MessageLookupByLibrary.simpleMessage("Сиды"),
    "sp_torrent_title": m37,
    "sp_translate": MessageLookupByLibrary.simpleMessage("Перевод"),
    "split_follows_divider": MessageLookupByLibrary.simpleMessage(
      "разделение по разделителю",
    ),
    "sync_group": MessageLookupByLibrary.simpleMessage("Синхронизация группы"),
    "sync_history": MessageLookupByLibrary.simpleMessage(
      "Синхронизация истории",
    ),
    "sync_quick_search": MessageLookupByLibrary.simpleMessage(
      "Синхронизация быстрого поиска",
    ),
    "sync_read_progress": MessageLookupByLibrary.simpleMessage(
      "Синхронизация прогресса чтения",
    ),
    "system_proxy": MessageLookupByLibrary.simpleMessage("Системное Прокси"),
    "system_share": MessageLookupByLibrary.simpleMessage(
      "Поделиться через....",
    ),
    "t_Clear_all_history": MessageLookupByLibrary.simpleMessage(
      "Очистить всю историю",
    ),
    "tab_download": MessageLookupByLibrary.simpleMessage("Загрузки"),
    "tab_favorite": MessageLookupByLibrary.simpleMessage("Избранное"),
    "tab_gallery": MessageLookupByLibrary.simpleMessage("Галерея"),
    "tab_history": MessageLookupByLibrary.simpleMessage("История"),
    "tab_history_duo_sidebar_note": MessageLookupByLibrary.simpleMessage(
      "Вкладка «История» не отображается на боковой панели iPhone Duo; открыть историю можно через панель действий страницы.",
    ),
    "tab_popular": MessageLookupByLibrary.simpleMessage("Популярное"),
    "tab_setting": MessageLookupByLibrary.simpleMessage("Настройки"),
    "tab_sort": MessageLookupByLibrary.simpleMessage(
      "Сделайте долгий тап и перемещайте для сортировки",
    ),
    "tab_toplist": MessageLookupByLibrary.simpleMessage("Лучшее"),
    "tab_watched": MessageLookupByLibrary.simpleMessage("Отслеживаемое"),
    "tabbar_setting": MessageLookupByLibrary.simpleMessage(
      "Настройки нижней панели",
    ),
    "tablet_layout": MessageLookupByLibrary.simpleMessage("Tablet layout"),
    "tagNamespace": m38,
    "tag_add_to_mytag": MessageLookupByLibrary.simpleMessage(
      "Добавить в мои теги",
    ),
    "tag_dialog_Default_color": MessageLookupByLibrary.simpleMessage(
      "Цвет по умолчанию",
    ),
    "tag_dialog_Hide": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "tag_dialog_TagColor": MessageLookupByLibrary.simpleMessage("Цвет"),
    "tag_dialog_Watch": MessageLookupByLibrary.simpleMessage(
      "Показывать материалы с тегом",
    ),
    "tag_dialog_tagWeight": MessageLookupByLibrary.simpleMessage(
      "Значимость тега",
    ),
    "tag_limit": MessageLookupByLibrary.simpleMessage("Лимит тегов"),
    "tag_vote_down": MessageLookupByLibrary.simpleMessage("Дизлайкнуть тег"),
    "tag_vote_up": MessageLookupByLibrary.simpleMessage("Лайкнуть тег"),
    "tag_withdraw_vote": MessageLookupByLibrary.simpleMessage(
      "убрать лайк/дизлайк с тега",
    ),
    "tags": MessageLookupByLibrary.simpleMessage("Теги"),
    "tap_to_turn_page_anima": MessageLookupByLibrary.simpleMessage(
      "Анимированные переходы страниц",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "thumbnails": MessageLookupByLibrary.simpleMessage("Превью"),
    "title": MessageLookupByLibrary.simpleMessage("Title"),
    "title_showing": MessageLookupByLibrary.simpleMessage("Показано"),
    "tolist_alltime": MessageLookupByLibrary.simpleMessage("За всё время"),
    "tolist_past_month": MessageLookupByLibrary.simpleMessage("За месяц"),
    "tolist_past_year": MessageLookupByLibrary.simpleMessage("За год"),
    "tolist_yesterday": MessageLookupByLibrary.simpleMessage(
      "За вчерашний день",
    ),
    "top_to_bottom": MessageLookupByLibrary.simpleMessage("Вертикально"),
    "turn_page_anima": MessageLookupByLibrary.simpleMessage(
      "Анимированные переходы страниц",
    ),
    "uc_Chinese": MessageLookupByLibrary.simpleMessage("Китайский"),
    "uc_Dutch": MessageLookupByLibrary.simpleMessage("Голландский"),
    "uc_English": MessageLookupByLibrary.simpleMessage("Английский"),
    "uc_French": MessageLookupByLibrary.simpleMessage("Французский"),
    "uc_German": MessageLookupByLibrary.simpleMessage("Немецкий"),
    "uc_Hungarian": MessageLookupByLibrary.simpleMessage("Венгерский"),
    "uc_Italian": MessageLookupByLibrary.simpleMessage("Итальянский"),
    "uc_Japanese": MessageLookupByLibrary.simpleMessage("Японский"),
    "uc_Korean": MessageLookupByLibrary.simpleMessage("Корейский"),
    "uc_NA": MessageLookupByLibrary.simpleMessage("N/A"),
    "uc_Original": MessageLookupByLibrary.simpleMessage("Оригинальная"),
    "uc_Other": MessageLookupByLibrary.simpleMessage("Другой"),
    "uc_Polish": MessageLookupByLibrary.simpleMessage("Польский"),
    "uc_Portuguese": MessageLookupByLibrary.simpleMessage("Португальский"),
    "uc_Rewrite": MessageLookupByLibrary.simpleMessage("Переписано"),
    "uc_Russian": MessageLookupByLibrary.simpleMessage("Русский"),
    "uc_Spanish": MessageLookupByLibrary.simpleMessage("Испанский"),
    "uc_Thai": MessageLookupByLibrary.simpleMessage("Тайский"),
    "uc_Translated": MessageLookupByLibrary.simpleMessage("Переведено"),
    "uc_Vietnamese": MessageLookupByLibrary.simpleMessage("Вьетнамский"),
    "uc_ar_0": MessageLookupByLibrary.simpleMessage(
      "Ручной выбор, Ручной запуск (По умолчанию)",
    ),
    "uc_ar_1": MessageLookupByLibrary.simpleMessage(
      "Ручной выбор, Автоматический запуск",
    ),
    "uc_ar_2": MessageLookupByLibrary.simpleMessage(
      "Автоматический выбор исходных изображений, Ручной запуск",
    ),
    "uc_ar_3": MessageLookupByLibrary.simpleMessage(
      "Автоматический выбор исходных изображений, Автоматический запуск",
    ),
    "uc_ar_4": MessageLookupByLibrary.simpleMessage(
      "Автоматический выбор сжатых изображений, Ручной запуск",
    ),
    "uc_ar_5": MessageLookupByLibrary.simpleMessage(
      "Автоматический выбор сжатых изображенийe, Автоматический запуск",
    ),
    "uc_archiver_desc": MessageLookupByLibrary.simpleMessage(
      "Изначально роль архиватора состоит в том, чтобы рассчитать траты и выбрать исходный или сжатый архив, а затем представить ссылку, по которой можно перейти или скопировать в другое место. Вы можете изменить это здесь",
    ),
    "uc_archiver_set": MessageLookupByLibrary.simpleMessage(
      "Настройки архиватора",
    ),
    "uc_artist": MessageLookupByLibrary.simpleMessage("artist"),
    "uc_auto": MessageLookupByLibrary.simpleMessage("Автоматически"),
    "uc_character": MessageLookupByLibrary.simpleMessage("character"),
    "uc_comments_show_votes": MessageLookupByLibrary.simpleMessage(
      "Показ голосов",
    ),
    "uc_comments_sort_order": MessageLookupByLibrary.simpleMessage(
      "Порядок сортировки",
    ),
    "uc_crt_profile": MessageLookupByLibrary.simpleMessage(
      "Создать новый профиль",
    ),
    "uc_cs_0": MessageLookupByLibrary.simpleMessage("Сначала старые"),
    "uc_cs_1": MessageLookupByLibrary.simpleMessage("Сначала новые"),
    "uc_cs_2": MessageLookupByLibrary.simpleMessage("Самые лайкнутые"),
    "uc_del_profile": MessageLookupByLibrary.simpleMessage("Удалить профиль"),
    "uc_dm_0": MessageLookupByLibrary.simpleMessage("Компактный"),
    "uc_dm_1": MessageLookupByLibrary.simpleMessage(
      "Отображение миниатюр изображений",
    ),
    "uc_dm_2": MessageLookupByLibrary.simpleMessage("Расширенный"),
    "uc_dm_3": MessageLookupByLibrary.simpleMessage("Минималистичный"),
    "uc_dm_4": MessageLookupByLibrary.simpleMessage("Минималистичный+"),
    "uc_exc_lang": MessageLookupByLibrary.simpleMessage("Исключенные языки"),
    "uc_exc_lang_desc": MessageLookupByLibrary.simpleMessage(
      "Если вы хотите скрыть галереи на определенных языках из списка галерей и результатов поиска, выберите их из списка выше.\n Обратите внимание, что соответствующие галереи никогда не появятся независимо от вашего поискового запроса",
    ),
    "uc_exc_up": MessageLookupByLibrary.simpleMessage("Исключенные загрузчики"),
    "uc_exc_up_desc": MessageLookupByLibrary.simpleMessage(
      "Если вы хотите скрыть галереи от определенных загрузчиков из списка галерей и поиска, добавьте их выше. Введите одно имя пользователя в строку. Обратите внимание, что галереи от этих загрузчиков никогда не появятся, независимо от вашего поискового запроса",
    ),
    "uc_fav": MessageLookupByLibrary.simpleMessage("Избранные"),
    "uc_fav_sort": MessageLookupByLibrary.simpleMessage(
      "Сортировка по умолчанию",
    ),
    "uc_fav_sort_desc": MessageLookupByLibrary.simpleMessage(
      "Вы также можете выбрать порядок сортировки галерей по умолчанию на странице избранного. Обратите внимание, что избранное, добавленное до обновления в марте 2016 года, не сохраняло временную метку и будет использовать время публикации в галерее независимо от этого параметра",
    ),
    "uc_female": MessageLookupByLibrary.simpleMessage("female"),
    "uc_front_page": MessageLookupByLibrary.simpleMessage("Главная страница"),
    "uc_front_page_dis_mode": MessageLookupByLibrary.simpleMessage(
      "Режим отображения главной страницы",
    ),
    "uc_fs_0": MessageLookupByLibrary.simpleMessage(
      "По времени обновления галереии",
    ),
    "uc_fs_1": MessageLookupByLibrary.simpleMessage(
      "По времени добавления в избранное",
    ),
    "uc_gallery_comments": MessageLookupByLibrary.simpleMessage(
      "Комментарии галереи",
    ),
    "uc_group": MessageLookupByLibrary.simpleMessage("group"),
    "uc_hath_local_host": MessageLookupByLibrary.simpleMessage(
      "Hentai@Home Local Network Host",
    ),
    "uc_hath_local_host_desc": MessageLookupByLibrary.simpleMessage(
      "Эта настройка может быть использована, если у вас в локальной сети запущен клиент H@H с тем же публичным IP адресом, с которым вы пользуетесь приложением. Некоторые маршрутизаторы глючат и не могут направить запросы к собственному IP; с помощью этого вы можете обойти данную проблема.\nЕсли клиент запущен на том же ПК, на котором запущено данное приложение, следует использовать адрес 127.0.0.1:port. Если клиент запущен на другом ПК в той же локальной сети, используйте его локальный IP адрес. Некоторые настройки браузера предотвращают запросы к внешним сайтам с IP адресов в локальной сети, для того, чтобы это работало, необходимо добавить сайт в список исключений",
    ),
    "uc_img_cussize_desc": MessageLookupByLibrary.simpleMessage(
      "Хотя сайт автоматически уменьшит масштаб изображений в соответствии с разрешением экрана, вы также можете вручную ограничить максимальное разрешение изображения. Как и при автоматическом масштабировании, это не приводит к изменению разрешения изображения в приложении, так как изменение разрешения происходит на стороне браузера. (0 = нет ограничений)",
    ),
    "uc_img_horiz": MessageLookupByLibrary.simpleMessage("По горизонтали"),
    "uc_img_load_setting": MessageLookupByLibrary.simpleMessage(
      "Настройки загрузки изображения",
    ),
    "uc_img_size_setting": MessageLookupByLibrary.simpleMessage(
      "Настройки размера изображения",
    ),
    "uc_img_vert": MessageLookupByLibrary.simpleMessage("По вертикали"),
    "uc_ip_addr_port": MessageLookupByLibrary.simpleMessage("IP Адрес:Порт"),
    "uc_language": MessageLookupByLibrary.simpleMessage("language"),
    "uc_lt_0": MessageLookupByLibrary.simpleMessage(
      "При наведении курсора на миниатюру (страницы загружаются быстрее, но может возникнуть небольшая задержка, прежде чем миниатюра появится)",
    ),
    "uc_lt_0_s": MessageLookupByLibrary.simpleMessage("При наведении мыши"),
    "uc_lt_1": MessageLookupByLibrary.simpleMessage(
      "При загрузке страницы (загрузка страниц занимает больше времени, но отсутствует задержка при загрузке миниатюр)",
    ),
    "uc_lt_1_s": MessageLookupByLibrary.simpleMessage("При загрузке страницы"),
    "uc_male": MessageLookupByLibrary.simpleMessage("male"),
    "uc_mose_over_thumb": MessageLookupByLibrary.simpleMessage(
      "Наведение курсора мыши на миниатюры",
    ),
    "uc_mpv": MessageLookupByLibrary.simpleMessage("Многостраничная читалка"),
    "uc_mpv_always": MessageLookupByLibrary.simpleMessage(
      "Всегда использовать",
    ),
    "uc_mpv_stype": MessageLookupByLibrary.simpleMessage("Стиль отображения"),
    "uc_mpv_thumb_pane": MessageLookupByLibrary.simpleMessage("Лента миниатюр"),
    "uc_ms_0": MessageLookupByLibrary.simpleMessage(
      "Выровнять по левому краю;\n масштабировать только в том случае, если изображение больше ширины браузера",
    ),
    "uc_ms_1": MessageLookupByLibrary.simpleMessage(
      "Выровнять по центру;\n масштабировать только в том случае, если изображение больше ширины браузера",
    ),
    "uc_ms_2": MessageLookupByLibrary.simpleMessage(
      "Выровнять по центру;\n всегда масштабировать изображения в соответствии с шириной браузера",
    ),
    "uc_mt_0": MessageLookupByLibrary.simpleMessage("Показать"),
    "uc_mt_1": MessageLookupByLibrary.simpleMessage("Скрыть"),
    "uc_name_display": MessageLookupByLibrary.simpleMessage(
      "Отображение названия галереи",
    ),
    "uc_name_display_desc": MessageLookupByLibrary.simpleMessage(
      "Многие галереи имеют как английское/латинизированное название, так и название, написанное японским шрифтом. Какое название галереи вы хотели бы видеть по умолчанию?",
    ),
    "uc_oi_0": MessageLookupByLibrary.simpleMessage("Prefer resampled images"),
    "uc_oi_1": MessageLookupByLibrary.simpleMessage("Prefer original images"),
    "uc_ori_image": MessageLookupByLibrary.simpleMessage(
      "Исходные изображения",
    ),
    "uc_ori_image_desc": MessageLookupByLibrary.simpleMessage(
      "Use original images instead of the resampled versions? Resampled images will still be used if you select a horizonal resolution different than \"Auto\" above and the image in question is wider, or if the original image is larger than 10 MiB (or 4 MiB for galleries older than one year).",
    ),
    "uc_parody": MessageLookupByLibrary.simpleMessage("parody"),
    "uc_pixels": MessageLookupByLibrary.simpleMessage("pixels"),
    "uc_pn_0": MessageLookupByLibrary.simpleMessage("None"),
    "uc_pn_1": MessageLookupByLibrary.simpleMessage("Page Number Only"),
    "uc_pn_2": MessageLookupByLibrary.simpleMessage("Page Number + Name"),
    "uc_profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "uc_qb_0": MessageLookupByLibrary.simpleMessage("Неа"),
    "uc_qb_1": MessageLookupByLibrary.simpleMessage("Ага"),
    "uc_rating": MessageLookupByLibrary.simpleMessage("Цвета рейтинга"),
    "uc_rating_desc": MessageLookupByLibrary.simpleMessage(
      "По умолчанию галереи, которые вы оценили, будут отмечены красными звездочками для оценок от 2 звезд и ниже, зелеными - для оценок от 2,5 до 4 звезд и синими - для оценок от 4,5 до 5 звезд. Вы можете настроить это, введя желаемую цветовую комбинацию ниже.\n Каждая буква представляет собой одну звезду. Значение RRGGB по умолчанию означает R(ed) для первой и второй звезды, G(reen) для третьей и четвертой и B(lue) для пятой. Вы также можете использовать (Y)ellow для обычных звезд. Любая комбинация из пяти букв R / G / B / Y работает",
    ),
    "uc_reclass": MessageLookupByLibrary.simpleMessage("reclass"),
    "uc_rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "uc_res_res": MessageLookupByLibrary.simpleMessage("Сжатие"),
    "uc_res_res_desc": MessageLookupByLibrary.simpleMessage(
      "Images are normally resampled to 1280 pixels of horizontal resolution for online viewing. You can select one of the following alternative resolutions.",
    ),
    "uc_sc_0": MessageLookupByLibrary.simpleMessage(
      "При наведении или нажатии",
    ),
    "uc_sc_1": MessageLookupByLibrary.simpleMessage("Всегда"),
    "uc_search_r_count": MessageLookupByLibrary.simpleMessage(
      "Счетчик результатов поиска",
    ),
    "uc_search_r_count_desc": MessageLookupByLibrary.simpleMessage(
      "Сколько результатов вы хотели бы получить для страниц индекса/поиска и страниц поиска торрентов? (Hath Perk: Paging Enlargement Required)",
    ),
    "uc_selected": MessageLookupByLibrary.simpleMessage("Выбранный"),
    "uc_set_as_def": MessageLookupByLibrary.simpleMessage(
      "Установить как профиль по умолчанию",
    ),
    "uc_show_page_num": MessageLookupByLibrary.simpleMessage(
      "Thumbnail Labeling",
    ),
    "uc_tag": MessageLookupByLibrary.simpleMessage("Теги галереи"),
    "uc_tag_ft": MessageLookupByLibrary.simpleMessage("Порог фильтрации тегов"),
    "uc_tag_ft_desc": MessageLookupByLibrary.simpleMessage(
      "Вы можете аккуратно фильтровать теги, добавляя их в (мои теги) с отрицательным приоритетом. Если в галерее есть теги, суммарный приоритет которых превышает это значение, она не появится при поиске. Этот порог может быть установлен в диапазоне от 0 до -9999",
    ),
    "uc_tag_namesp": MessageLookupByLibrary.simpleMessage("Группы тегов"),
    "uc_tag_short_order": MessageLookupByLibrary.simpleMessage(
      "Порядок сортировки тегов галереи",
    ),
    "uc_tag_wt": MessageLookupByLibrary.simpleMessage(
      "Порог отображения тегов",
    ),
    "uc_tag_wt_desc": MessageLookupByLibrary.simpleMessage(
      "Недавно загруженные галереи будут отображаться в отслеживаемом, если в них есть хотя бы один тег с положительным приоритетом, и сумма приоритета в его просмотренных тегах составляет это значение или выше. Этот порог может быть установлен в диапазоне от 0 до 9999",
    ),
    "uc_tb_0": MessageLookupByLibrary.simpleMessage("По алфавиту"),
    "uc_tb_1": MessageLookupByLibrary.simpleMessage("По количеству тегов"),
    "uc_thor_hath": MessageLookupByLibrary.simpleMessage("Через H@H"),
    "uc_thumb_row": MessageLookupByLibrary.simpleMessage("Количество строк"),
    "uc_thumb_scaling": MessageLookupByLibrary.simpleMessage(
      "Масштабирование миниатюр",
    ),
    "uc_thumb_scaling_desc": MessageLookupByLibrary.simpleMessage(
      "Просто миниатюры и миниатюры из расширенного списка галерей можно масштабировать до настраиваемого значения от 75% до 150%",
    ),
    "uc_thumb_setting": MessageLookupByLibrary.simpleMessage(
      "Настройки миниатюр изображений",
    ),
    "uc_thumb_size": MessageLookupByLibrary.simpleMessage("Размер"),
    "uc_tl_0": MessageLookupByLibrary.simpleMessage("Название по умолчанию"),
    "uc_tl_1": MessageLookupByLibrary.simpleMessage(
      "Название на японском (если доступно)",
    ),
    "uc_ts_0": MessageLookupByLibrary.simpleMessage("Auto"),
    "uc_ts_1": MessageLookupByLibrary.simpleMessage("Normal"),
    "uc_ts_2": MessageLookupByLibrary.simpleMessage("Small"),
    "uc_uh_0": MessageLookupByLibrary.simpleMessage(
      "Любой клиент (Рекомендуется)",
    ),
    "uc_uh_0_s": MessageLookupByLibrary.simpleMessage("Любой клиент"),
    "uc_uh_1": MessageLookupByLibrary.simpleMessage(
      "Только клиенты с портами по умолчанию (Может быть достаточно медленным. Используйте, если брандмауэр/прокси блокируют нестандартные порты)",
    ),
    "uc_uh_1_s": MessageLookupByLibrary.simpleMessage(
      "Только клиенты с портами по умолчанию",
    ),
    "uc_uh_2": MessageLookupByLibrary.simpleMessage(
      "Нет [Современный метод/HTTPS] (Только для донатеров. Вы не сможете просматривать очень много страниц. Рекомендуется только если есть проблемы с другими методами)",
    ),
    "uc_uh_2_s": MessageLookupByLibrary.simpleMessage(
      "Нет [Современный метод/HTTPS]",
    ),
    "uc_uh_3": MessageLookupByLibrary.simpleMessage(
      "Нет [Устаревший метод/HTTP] (Только для донатеров. Может не работать в современных браузерах. Рекомендуется только для устаревших браузеров)",
    ),
    "uc_uh_3_s": MessageLookupByLibrary.simpleMessage(
      "Нет [Устаревший метод/HTTP]",
    ),
    "uc_viewport_or": MessageLookupByLibrary.simpleMessage(
      "Переопределение ширины приложения",
    ),
    "uc_viewport_or_desc": MessageLookupByLibrary.simpleMessage(
      "Позволяет переопределить виртуальную ширину приложения для мобильных устройств. Обычно она автоматически определяется вашим устройством на основе его точек на дюйм. Допустимые значения при 100%-ном масштабе миниатюр находятся в диапазоне от 640 до 1400",
    ),
    "uc_xt_desc": MessageLookupByLibrary.simpleMessage(
      "Если вы хотите исключить определенные группы тегов из поиска по тегам по умолчанию, вы можете отметить их выше. Обратите внимание, что это не препятствует появлению галерей с тегами из этих групп, это просто делает так, что при поиске тегов он упустит их",
    ),
    "unlimited": MessageLookupByLibrary.simpleMessage("Без ограничения"),
    "update_to_version": m39,
    "upload_avatar": MessageLookupByLibrary.simpleMessage("Загрузить аватар"),
    "uploader": MessageLookupByLibrary.simpleMessage("Загрузчик"),
    "user_login": MessageLookupByLibrary.simpleMessage("Вход в аккаунт"),
    "user_name": MessageLookupByLibrary.simpleMessage("Логин"),
    "version": MessageLookupByLibrary.simpleMessage("Версия"),
    "vibrate_feedback": MessageLookupByLibrary.simpleMessage("Вибрация"),
    "volume_key_turn_page": MessageLookupByLibrary.simpleMessage(
      "Переключение страниц кнопкой громкости",
    ),
    "vote_down_successfully": MessageLookupByLibrary.simpleMessage(
      "Дизлайк успешно поставлен",
    ),
    "vote_successfully": MessageLookupByLibrary.simpleMessage(
      "Голос успешно отдан",
    ),
    "vote_up_successfully": MessageLookupByLibrary.simpleMessage(
      "Лайк успешно поставлен",
    ),
    "webdav_Account": MessageLookupByLibrary.simpleMessage("Аккаунт WebDAV"),
    "webdav_max_connections": MessageLookupByLibrary.simpleMessage(
      "WebDAV Max Connections",
    ),
    "welcome_text": MessageLookupByLibrary.simpleMessage("~ах~ ах~ ах~~~"),
  };
}
