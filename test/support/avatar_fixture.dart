import 'dart:convert';

final neutralAvatarPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
  '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);
const avatarFormHtml =
    '<form action="index.php?auth_key=0123456789abcdef0123456789abcdef">'
    '<input name="CODE" value="25"><input name="upload_avatar" type="file"></form>';
