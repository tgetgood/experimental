; ModuleID = 'example.c'
source_filename = "example.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@.str = private unnamed_addr constant [5 x i8] c"%ld\0A\00", align 1

; Function Attrs: nofree nosync nounwind readnone sspstrong uwtable
define dso_local i64 @fib(i32 %0) local_unnamed_addr #0 {
  switch i32 %0, label %3 [
    i32 0, label %9
    i32 1, label %2
  ]

2:                                                ; preds = %1
  br label %9

3:                                                ; preds = %1
  %4 = add nsw i32 %0, -1
  %5 = call i64 @fib(i32 %4)
  %6 = add nsw i32 %0, -2
  %7 = call i64 @fib(i32 %6)
  %8 = add nsw i64 %7, %5
  br label %9

9:                                                ; preds = %1, %3, %2
  %10 = phi i64 [ 1, %2 ], [ %8, %3 ], [ 0, %1 ]
  ret i64 %10
}

; Function Attrs: nofree nounwind sspstrong uwtable
define dso_local i32 @readInput() local_unnamed_addr #1 {
  %1 = alloca [10 x i8], align 1
  %2 = getelementptr inbounds [10 x i8], [10 x i8]* %1, i64 0, i64 0
  %3 = alloca i8, align 1
  %4 = getelementptr inbounds [10 x i8], [10 x i8]* %1, i64 0, i64 0
  call void @llvm.lifetime.start.p0i8(i64 10, i8* nonnull %4) #8
  call void @llvm.lifetime.start.p0i8(i64 1, i8* nonnull %3) #8
  %5 = call i64 @read(i32 0, i8* nonnull %3, i64 1) #8
  %6 = load i8, i8* %3, align 1, !tbaa !5
  %7 = icmp eq i8 %6, 10
  br i1 %7, label %18, label %8

8:                                                ; preds = %0, %8
  %9 = phi i64 [ %12, %8 ], [ 0, %0 ]
  %10 = phi i8 [ %14, %8 ], [ %6, %0 ]
  %11 = getelementptr inbounds [10 x i8], [10 x i8]* %1, i64 0, i64 %9
  store i8 %10, i8* %11, align 1, !tbaa !5
  %12 = add nuw i64 %9, 1
  %13 = call i64 @read(i32 0, i8* nonnull %3, i64 1) #8
  %14 = load i8, i8* %3, align 1, !tbaa !5
  %15 = icmp eq i8 %14, 10
  br i1 %15, label %16, label %8, !llvm.loop !8

16:                                               ; preds = %8
  %17 = trunc i64 %12 to i32
  br label %18

18:                                               ; preds = %16, %0
  %19 = phi i32 [ 0, %0 ], [ %17, %16 ]
  %20 = add nuw nsw i32 %19, 1
  %21 = zext i32 %20 to i64
  %22 = call i8* @llvm.stacksave()
  %23 = alloca i8, i64 %21, align 16
  %24 = icmp eq i32 %19, 0
  br i1 %24, label %27, label %25

25:                                               ; preds = %18
  %26 = zext i32 %19 to i64
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* nonnull align 16 %23, i8* nonnull align 1 %2, i64 %26, i1 false)
  br label %27

27:                                               ; preds = %25, %18
  %28 = zext i32 %19 to i64
  %29 = getelementptr inbounds i8, i8* %23, i64 %28
  store i8 0, i8* %29, align 1, !tbaa !5
  %30 = call i64 @strtol(i8* nocapture nonnull %23, i8** null, i32 10) #8
  %31 = trunc i64 %30 to i32
  call void @llvm.stackrestore(i8* %22)
  call void @llvm.lifetime.end.p0i8(i64 1, i8* nonnull %3) #8
  call void @llvm.lifetime.end.p0i8(i64 10, i8* nonnull %4) #8
  ret i32 %31
}

; Function Attrs: argmemonly mustprogress nofree nosync nounwind willreturn
declare void @llvm.lifetime.start.p0i8(i64 immarg, i8* nocapture) #2

; Function Attrs: nofree
declare noundef i64 @read(i32 noundef, i8* nocapture noundef, i64 noundef) local_unnamed_addr #3

; Function Attrs: mustprogress nofree nosync nounwind willreturn
declare i8* @llvm.stacksave() #4

; Function Attrs: argmemonly mustprogress nofree nosync nounwind willreturn
declare void @llvm.lifetime.end.p0i8(i64 immarg, i8* nocapture) #2

; Function Attrs: mustprogress nofree nosync nounwind willreturn
declare void @llvm.stackrestore(i8*) #4

; Function Attrs: nofree nounwind sspstrong uwtable
define dso_local i32 @main() local_unnamed_addr #1 {
  %1 = call i32 @readInput()
  %2 = call i64 @fib(i32 %1)
  %3 = call i32 (i8*, ...) @printf(i8* nonnull dereferenceable(1) getelementptr inbounds ([5 x i8], [5 x i8]* @.str, i64 0, i64 0), i64 %2)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(i8* nocapture noundef readonly, ...) local_unnamed_addr #5

; Function Attrs: mustprogress nofree nounwind willreturn
declare i64 @strtol(i8* readonly, i8** nocapture, i32) local_unnamed_addr #6

; Function Attrs: argmemonly nofree nounwind willreturn
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg) #7

attributes #0 = { nofree nosync nounwind readnone sspstrong uwtable "frame-pointer"="none" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nofree nounwind sspstrong uwtable "frame-pointer"="none" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { argmemonly mustprogress nofree nosync nounwind willreturn }
attributes #3 = { nofree "frame-pointer"="none" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { mustprogress nofree nosync nounwind willreturn }
attributes #5 = { nofree nounwind "frame-pointer"="none" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { mustprogress nofree nounwind willreturn "frame-pointer"="none" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #7 = { argmemonly nofree nounwind willreturn }
attributes #8 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 7, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 1}
!4 = !{!"clang version 13.0.1"}
!5 = !{!6, !6, i64 0}
!6 = !{!"omnipotent char", !7, i64 0}
!7 = !{!"Simple C/C++ TBAA"}
!8 = distinct !{!8, !9}
!9 = !{!"llvm.loop.unroll.disable"}
