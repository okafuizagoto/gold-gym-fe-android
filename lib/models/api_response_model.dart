class ApiResponse<T> {
  final T? data;
  final Map<String, dynamic>? metadata;
  final ApiError error;

  ApiResponse({
    this.data,
    this.metadata,
    required this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      metadata: json['metadata'],
      error: ApiError.fromJson(json['error'] ?? {}),
    );
  }

  bool get isSuccess => error.status == false;
}

class ApiError {
  final bool status;
  final String message;

  ApiError({
    required this.status,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
