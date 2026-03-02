import '../services/api_service.dart';

String mapErrorToZh(Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'bad_request':
        return '请求参数不正确：${error.message}';
      case 'not_found':
        return '未找到对应数据：${error.message}';
      case 'conflict':
        return '操作冲突：${error.message}';
      case 'internal_error':
        return '服务端内部错误：${error.message}';
      default:
        return '请求失败：${error.message}';
    }
  }
  return '发生异常：$error';
}
