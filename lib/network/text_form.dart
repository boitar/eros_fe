import 'package:dio/dio.dart';

/// Only verified text-only endpoints use this; file uploads stay multipart.
Options textFormOptions(Options base) =>
    base.copyWith(contentType: Headers.formUrlEncodedContentType);
