import 'dart:ui';

/// 基础画布栅格：所有组件吸附和背景网格共用这一个单位。
const double kGridUnit = 20.0;

/// 把一个标量值吸附到最近的 20px 格点。
double snapValueToGrid(double value) {
  return (value / kGridUnit).roundToDouble() * kGridUnit;
}

/// 把一个坐标吸附到最近的 20px 格点。
Offset snapOffsetToGrid(Offset position) {
  return Offset(
    snapValueToGrid(position.dx),
    snapValueToGrid(position.dy),
  );
}
