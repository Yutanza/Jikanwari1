// import XCTest
// import SwiftData
// @testable import Jikanwari1 // 自分のターゲット名に書き換えてください

// final class LessonGenerationTests: XCTestCase {
//     var container: ModelContainer!
//     var context: ModelContext!

//     override func setUp() {
//         super.setUp()
//         // テスト用のインメモリコンテナを作成
//         let config = ModelConfiguration(isStoredInMemoryOnly: true)
//         container = try! ModelContainer(for: Lesson.self, Subject.self, Timetable.self, configurations: config)
//         context = ModelContext(container)
//     }

//     func testGenerateLessonsCount() {
//         // 1. 準備：1週間の期間を設定
//         let start = Calendar.current.date(from: DateComponents(year: 2024, month: 4, day: 1))! // 月曜日
//         let end = Calendar.current.date(from: DateComponents(year: 2024, month: 4, day: 14))!  // 2週間後
//         let timetable = Timetable(name: "春学期", startDate: start, endDate: end)
        
//         let subject = Subject(title: "プログラミング基礎")
//         let period = PeriodSetting(periodNumber: 1, startHour: 9, startMinute: 0, endHour: 10, endMinute: 30)
        
//         let schedule = SubjectSchedule(dayOfWeek: .monday, period: period)
        
//         // 2. 実行：月曜日の授業を生成
//         let lessons = LessonGenerator.generateLessons(for: timetable, schedule: schedule, subject: subject)
        
//         // 3. 検証：2週間分なので2つのLessonが生成されるはず
//         XCTAssertEqual(lessons.count, 2, "2週間の期間内に月曜日は2回あるはずです")
//         XCTAssertEqual(lessons.first?.date, start)
//     }
// }


import XCTest
import SwiftData
@testable import Jikanwari1 // 自分のターゲット名に書き換えてください

final class SwiftDataPersistenceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        // テスト用のインメモリ設定
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Subject.self, SubjectSchedule.self, configurations: config)
        context = ModelContext(container)
    }

    func testInsertAndFetchSubject() throws {
        // 1. 新規データの作成
        let newSubject = Subject(title: "数学I", teacher: "山田太郎", room: "101教室")
        
        // 2. データの挿入と保存
        context.insert(newSubject)
        try context.save() // 明示的に保存を実行
        
        // 3. データの取得（Fetch）
        let descriptor = FetchDescriptor<Subject>()
        let fetchedSubjects = try context.fetch(descriptor)
        
        // 4. 検証
        XCTAssertEqual(fetchedSubjects.count, 1)
        XCTAssertEqual(fetchedSubjects.first?.title, "数学I")
    }

    func testRelationshipPersistence() throws {
        // 1. 教科とスケジュールを作成して紐付け
        let subject = Subject(title: "英語")
        let schedule = SubjectSchedule(dayOfWeek: .monday)
        
        // Subjectのschedules配列に追加（SwiftDataがリレーションシップを管理）
        subject.schedules.append(schedule)
        
        // 2. 親オブジェクトを保存
        context.insert(subject)
        try context.save()
        
        // 3. スケジュール単体で取得できるか確認
        let scheduleDescriptor = FetchDescriptor<SubjectSchedule>()
        let fetchedSchedules = try context.fetch(scheduleDescriptor)
        
        // 4. 検証：Subjectを保存すれば、紐づくScheduleも保存されているはず
        XCTAssertEqual(fetchedSchedules.count, 1)
        XCTAssertEqual(fetchedSchedules.first?.sourceSubject?.title, "英語")
    }
}
