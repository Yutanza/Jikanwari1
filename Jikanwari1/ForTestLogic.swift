import Foundation
import SwiftData

struct LessonGenerator {
    /// 指定された期間とスケジュールに基づいて、Lessonの配列を生成する
    static func generateLessons(for timetable: Timetable, schedule: SubjectSchedule, subject: Subject) -> [Lesson] {
        var generatedLessons: [Lesson] = []
        let calendar = Calendar.current
        
        // 開始日から終了日まで1日ずつループ
        var currentDate = timetable.startDate
        while currentDate <= timetable.endDate {
            let weekdayInt = calendar.component(.weekday, from: currentDate)
            
            // 曜日の合致判定 (Weekday enumのrawValueとCalendarの1-7を比較)
            if weekdayInt == schedule.dayOfWeek.rawValue {
                let newLesson = Lesson(
                    date: currentDate,
                    subject: subject,
                    sourceSchedule: schedule
                )
                newLesson.timetable = timetable
                generatedLessons.append(newLesson)
            }
            
            // 翌日へ
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return generatedLessons
    }
}
