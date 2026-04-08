import Foundation
import SwiftData

class LessonService {
    private var context: ModelContext
    private var calendar = Calendar.current
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Lessonの作成・取得
    
    /// 単発の授業（補講など）を生成する
    func createExtraLesson(date: Date, period: PeriodSetting, subject: Subject?, room: String? = nil, teacher: String? = nil) throws {
        // 単発用のイニシャライザを使用
        let newLesson = Lesson(date: date, period: period, subject: subject, room: room, teacher: teacher)
        newLesson.isExtra = true
        
        context.insert(newLesson)
        try context.save()
    }
    
    /// 指定した日付の授業一覧を取得し、開始時刻の昇順でソートして返す
    func fetchDailyLessons(for date: Date) throws -> [Lesson] {
        // 対象日の0:00〜23:59までの範囲を作成（SwiftDataでの日付検索を正確にするため）
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let predicate = #Predicate<Lesson> { lesson in
            lesson.date >= startOfDay && lesson.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<Lesson>(predicate: predicate)
        let lessons = try context.fetch(descriptor)
        
        // periodSnapの開始時刻（時、分）で昇順ソート
        return lessons.sorted {
            if $0.periodSnap.startHour != $1.periodSnap.startHour {
                return $0.periodSnap.startHour < $1.periodSnap.startHour
            }
            return $0.periodSnap.startMinute < $1.periodSnap.startMinute
        }
    }
    
    /// 特定の教科に紐づくすべての授業を取得する（過去・未来含む）
    func fetchLessons(for subject: Subject) -> [Lesson] {
        // リレーションを利用し、日付の昇順でソートして返す
        return subject.lessons.sorted { $0.date < $1.date }
    }
    
    // MARK: - 出欠と集計
    
    /// 出欠ステータスの集計と出席率の計算を行う
    func calculateAttendanceStatus(for subject: Subject) -> (present: Int, absent: Int, late: Int, authorized: Int, attendanceRate: Double) {
        let now = Date()
        
        // 過去の授業、かつ休講ではないものを対象とする
        let pastLessons = subject.lessons.filter { $0.date < now && !$0.isCancelled }
        
        var presentCount = 0
        var absentCount = 0
        var lateCount = 0
        var authorizedCount = 0
        
        for lesson in pastLessons {
            switch lesson.attendance {
            case .present: presentCount += 1
            case .absent: absentCount += 1
            case .late: lateCount += 1
            case .authorizedAbsence: authorizedCount += 1
            case .none: break
            }
        }
        
        // 出席率の計算（例: 公欠(authorized)は分母から除外、遅刻は出席としてカウントする場合）
        // ※ 大学や学校のルールに合わせて計算ロジックは調整してください。
        let totalEvaluated = presentCount + absentCount + lateCount
        var rate: Double = 0.0
        
        if totalEvaluated > 0 {
            rate = Double(presentCount + lateCount) / Double(totalEvaluated) * 100.0
        }
        
        return (presentCount, absentCount, lateCount, authorizedCount, rate)
    }
    
    /// 授業の出欠状態を記録・更新する
    func updateAttendance(lesson: Lesson, attendance: Attendance?) throws {
        lesson.attendance = attendance
        try context.save()
    }
    
    // MARK: - 詳細の更新・削除
    
    /// 授業のメモ、休講フラグ、教室、教員を更新する
    func updateLessonDetails(lesson: Lesson, note: String, isCancelled: Bool, room: String?, teacher: String?) throws {
        lesson.note = note
        lesson.isCancelled = isCancelled
        
        // 教室や教員が元の状態から変更された場合のみフラグを立てる
        if lesson.room != room || lesson.teacher != teacher {
            lesson.isManuallyRoomEdited = true
        }
        
        lesson.room = room
        lesson.teacher = teacher
        
        try context.save()
    }
    
    /// 個別の授業を削除する
    func deleteLesson(lesson: Lesson) throws {
        context.delete(lesson)
        try context.save()
    }
}
