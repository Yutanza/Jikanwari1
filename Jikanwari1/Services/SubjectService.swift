import Foundation
import SwiftData

class SubjectService {
    private var context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - 教科の作成・取得・検索
    
    /// 新規教科を作成する
    func createSubject(title: String, teacher: String = "", room: String = "") throws {
        let newSubject = Subject(title: title, teacher: teacher, room: room)
        context.insert(newSubject)
        try context.save()
    }
    
    /// 全ての教科を取得する
    func fetchAllSubjects() throws -> [Subject] {
        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.title)])
        return try context.fetch(descriptor)
    }
    
    /// キーワードで教科を検索する
    func searchSubjects(keyword: String) throws -> [Subject] {
        guard !keyword.isEmpty else { return try fetchAllSubjects() }
        
        let predicate = #Predicate<Subject> { subject in
            subject.title.localizedStandardContains(keyword) ||
            subject.teacher.localizedStandardContains(keyword)
        }
        let descriptor = FetchDescriptor<Subject>(predicate: predicate, sortBy: [SortDescriptor(\.title)])
        return try context.fetch(descriptor)
    }
    
    // MARK: - 更新・削除
    
    /// 教科情報を更新する
    func updateSubject(subject: Subject, title: String, teacher: String, room: String, updateFutureLessons: Bool) throws {
        subject.title = title
        subject.teacher = teacher
        subject.room = room
        
        if updateFutureLessons {
            let now = Date()
            let futureLessons = subject.lessons.filter { $0.date >= now }
            
            for lesson in futureLessons {
                // デフォルト教員の上書き
                lesson.teacher = teacher
                
                // 教室については、ユーザーが個別に「この日だけ教室変更」としていない場合のみ上書きする配慮
                if !lesson.isManuallyRoomEdited {
                    lesson.room = room
                }
            }
        }
        
        try context.save()
    }
    
    /// 削除時の影響範囲を計算する（View側での警告用）
    func checkDeletionImpact(for subject: Subject) -> (schedules: Int, lessons: Int, todos: Int) {
        let schedulesCount = subject.schedules.count
        let lessonsCount = subject.lessons.count
        let todosCount = subject.todoRules.count + subject.independentToDos.count
        return (schedulesCount, lessonsCount, todosCount)
    }
    
    /// 教科を削除する（Cascadeによって紐づくSchedule, Lesson, ToDoRuleなどが消えます）
    func deleteSubject(subject: Subject) throws {
        context.delete(subject)
        try context.save()
    }
}
