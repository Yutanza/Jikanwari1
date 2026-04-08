import Foundation
import SwiftData

class ScheduleService {
    private var context: ModelContext
    private var calendar = Calendar.current
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - スケジュール枠の作成とLesson生成
    
    /// スケジュール枠を作成し、該当するLessonを一括生成する
    func createSubjectSchedule(timetable: Timetable, dayOfWeek: Weekday, period: PeriodSetting, subject: Subject) throws {
        let schedule = SubjectSchedule(dayOfWeek: dayOfWeek, period: period)
        schedule.timetable = timetable
        schedule.sourceSubject = subject
        
        context.insert(schedule)
        
        // 期間内のLessonを一括生成
        generateLessons(for: schedule, in: timetable)
        
        try context.save()
    }
    
    // MARK: - スケジュール取得 (マトリクス生成)
    
    /// UI表示用に、1週間分のスケジュールをマトリクス（時限番号をキーとした辞書）にして返す
    /// 戻り値例: [1: [.monday: ScheduleA, .tuesday: ScheduleB], 2: [...]]
    func fetchWeeklySchedule(for timetable: Timetable) -> [Int: [Weekday: SubjectSchedule]] {
        var matrix: [Int: [Weekday: SubjectSchedule]] = [:]
        
        for schedule in timetable.schedules {
            let periodNum = schedule.period.periodNumber
            if matrix[periodNum] == nil {
                matrix[periodNum] = [:]
            }
            matrix[periodNum]?[schedule.dayOfWeek] = schedule
        }
        
        return matrix
    }
    
    // MARK: - 更新・削除
    
    /// スケジュール枠を更新し、未来のLessonを再生成する
    func updateSubjectSchedule(schedule: SubjectSchedule, newSubject: Subject, newDayOfWeek: Weekday, newPeriod: PeriodSetting) throws {
        guard let timetable = schedule.timetable else { return }
        let now = Date()
        
        // 1. 未来の既存Lessonを削除
        let futureLessons = schedule.lessons.filter { $0.date >= now }
        for lesson in futureLessons {
            context.delete(lesson)
        }
        
        // 2. スケジュール枠自体の情報を更新
        schedule.sourceSubject = newSubject
        schedule.dayOfWeek = newDayOfWeek
        schedule.period = newPeriod
        
        // 3. 今日の日付〜Timetable終了日までの間で、新しい条件のLessonを再生成
        let generateStartDate = max(now, timetable.startDate)
        generateLessons(for: schedule, startDate: generateStartDate, endDate: timetable.endDate)
        
        try context.save()
    }
    
    /// スケジュール枠を削除する
    func deleteSubjectSchedule(schedule: SubjectSchedule, deleteFutureLessons: Bool) throws {
        if deleteFutureLessons {
            let now = Date()
            let futureLessons = schedule.lessons.filter { $0.date >= now }
            for lesson in futureLessons {
                context.delete(lesson)
            }
        }
        // schedule自体を削除（これ以前のLessonはsourceScheduleがNullになるが履歴として残る）
        context.delete(schedule)
        try context.save()
    }
    
    // MARK: - Private Helpers (Lessonの自動生成ロジック)
    
    /// 特定のスケジュール枠に基づいて、指定期間内のLessonを一括生成する
    private func generateLessons(for schedule: SubjectSchedule, in timetable: Timetable) {
        generateLessons(for: schedule, startDate: timetable.startDate, endDate: timetable.endDate)
    }
    
    private func generateLessons(for schedule: SubjectSchedule, startDate: Date, endDate: Date) {
        var currentDate = startDate
        let targetWeekday = schedule.dayOfWeek.rawValue // 1:Sun, 2:Mon...
        
        // endDateまでループして、曜日が一致する日にLessonを生成
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            if weekday == targetWeekday {
                let newLesson = Lesson(date: currentDate, subject: schedule.sourceSubject, sourceSchedule: schedule)
                newLesson.timetable = schedule.timetable
                context.insert(newLesson)
            }
            
            // 翌日へ進める
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
    }
}
