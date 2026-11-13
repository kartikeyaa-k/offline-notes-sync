/// Pure-Dart building blocks for the **domain** layer of any feature.
///
/// Domain code imports only this library, never `package:core/core.dart`,
/// so it stays free of Flutter, storage and network dependencies.
library;

export 'src/result/resource.dart';
export 'src/use_case/use_case.dart';
