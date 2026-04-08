import Foundation
import SwiftData

class TimetableService {
    private var context: ModelContext

    // システム全体で保持する最大時限数（内部定数）
    private let maxPeriodCount = 10
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Timetable (時間割表) の操作
    
    /// 新規時間割表を作成し、最大時限数分のPeriodSettingを自動生成する
    func createTimetable(name: String, startDate: Date? = nil, endDate: Date? = nil, visiblePeriodCount: Int = 6) throws {
        let newTimetable = Timetable(name: name, startDate: startDate, endDate: endDate)
        newTimetable.visiblePeriodCount = visiblePeriodCount
        context.insert(newTimetable)
        
        
    
        
        try context.save()
    }
    
    /// 全てのTimetableを取得する
    func fetchAllTimetables() throws -> [Timetable] {
        // 開始日(startDate)の昇順でソートして取得
        let descriptor = FetchDescriptor<Timetable>(sortBy: [SortDescriptor(\.startDate)])
        return try context.fetch(descriptor)
    }
    
    /// 指定された日付が含まれるアクティブな時間割表を取得する
    func fetchActiveTimetable(for targetDate: Date = Date()) throws -> Timetable? {
        // SwiftDataのPredicateを使用して、対象日が期間内に収まっているものを検索
        let predicate = #Predicate<Timetable> { timetable in
            timetable.startDate <= targetDate && timetable.endDate >= targetDate
        }
        var descriptor = FetchDescriptor<Timetable>(predicate: predicate)
        descriptor.fetchLimit = 1 // 該当する最初の1件を取得
        
        return try context.fetch(descriptor).first
    }
    
    /// 時間割表の期間や名前を更新する
    func updateTimetable(_ timetable: Timetable, name: String=nil, startDate: Date=nil, endDate: Date=nil) throws {
        let oldStartDate = timetable.startDate
        let oldEndDate = timetable.endDate
        
        if name != nil { timetable.name = name }
        if startDate != nil { timetable.startDate = startDate }
        if endDate != nil { timetable.endDate = endDate }
        
        // 期間に変更があった場合、Lessonの追加・削除ハンドリングを行う
        if oldStartDate != startDate || oldEndDate != endDate {
            handleTimetablePeriodChange(
                timetable: timetable,
                oldStart: oldStartDate,
                oldEnd: oldEndDate,
                newStart: startDate,
                newEnd: endDate
            )
        }
        
        try context.save()
    }
    
    func deleteTimetable(_ timetable: Timetable) throws {
        // CascadeによってScheduleServiceは削除されるものの、そのScheduleに紐づくLessonは、nullify設定によって削除されない。
        // そのため、時間割削除時に、不要になる未来のLessonを手動で一掃する処理が必要になる
        let now = Date()
        let futureLessons = timetable.lessons.filter { $0.date >= now }
        for lesson in futureLessons {
            context.delete(lesson)
        }

        context.delete(timetable)
        try context.save()
    }
    
    
    // MARK: - PeriodSetting (時限設定) の操作
    
    
    /// 特定の時間割表に紐づく時限設定の一覧を取得する（昇順）
    func fetchPeriods(for timetable: Timetable) -> [PeriodSetting] {
        // リレーションから取得し、periodNumberで昇順ソートして返す
        return timetable.periodSettings.sorted { $0.periodNumber < $1.periodNumber }
    }
    
    /// 時限の時刻を更新し、未来のLessonとそのToDo期限に同期する
    func updatePeriod(period: PeriodSetting, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) throws {
        // 1. PeriodSetting自身の更新
        period.startHour = startHour
        period.startMinute = startMinute
        period.endHour = endHour
        period.endMinute = endMinute
        
        let now = Date()
        let calendar = Calendar.current
        
        // 2. この時限に紐づく未来のLessonと、関連ToDoの更新
        let futureLessons = period.lessons.filter { $0.date >= now }
        
        for lesson in futureLessons {
            // LessonのperiodSnapを上書き同期
            lesson.periodSnap.startHour = startHour
            lesson.periodSnap.startMinute = startMinute
            lesson.periodSnap.endHour = endHour
            lesson.periodSnap.endMinute = endMinute
            
            // 3. このLessonに紐づく未完了のルーティンToDoの期限(deadLine)を再計算
            let incompleteRoutineToDos = lesson.toDos.filter { !$0.isCompleted && $0.sourceRule != nil }
            
            for todo in incompleteRoutineToDos {
                guard let rule = todo.sourceRule else { continue }
                
                // timeModeが .relativeToLesson の場合のみ、時間がずれるので再計算が必要
                if rule.timeMode == .relativeToLesson {
                    
                    // 基準となる「授業予定日」を算出（相対日 relativeDay を加算）
                    guard let targetDate = calendar.date(byAdding: .day, value: rule.relativeDay, to: lesson.date) else { continue }
                    
                    // 新しい開始時刻をセット
                    guard let baseTime = calendar.date(bySettingHour: startHour,
                                                       minute: startMinute,
                                                       second: 0,
                                                       of: targetDate) else { continue }
                    
                    // オフセット（授業の何分前かなど）を加味して最終的な期限を算出
                    let offset = rule.offsetMinutes ?? 0
                    if let newDeadline = calendar.date(byAdding: .minute, value: offset, to: baseTime) {
                        todo.deadLine = newDeadline
                    }
                }
            }
        }
        
        try context.save()
    }
    
    /// 時間割の表示時限数を更新する
    func updateVisiblePeriodCount(for timetable: Timetable, newCount: Int) throws {
        guard newCount > 0 && newCount <= maxPeriodCount else { return }
        timetable.visiblePeriodCount = newCount
        try context.save()
    }
    
    
    // MARK: - Private Helpers
    
    /// 期間変更に伴うLessonの再計算ハンドリング（スタブ/呼び出し先）
    private func handleTimetablePeriodChange(timetable: Timetable, oldStart: Date, oldEnd: Date, newStart: Date, newEnd: Date) {
        // 実際の実装では、ここで以下のような処理を行います。
        // 1. 新しい期間外（newStartより前、またはnewEndより後）になってしまった既存Lessonの削除
        // 2. 期間が拡張された場合（newEndがoldEndより後など）、その分の空白期間に対して
        //    SubjectScheduleを元に新規Lessonを自動生成するロジックの呼び出し。
        
        // ※ Lessonの自動生成ロジックはLessonService等に切り出すか、ここでScheduleをループして生成します。
        print("期間が変更されました。対象Timetable: \(timetable.name)。必要に応じてLessonの再生成/削除を実行します。")
    }
}
