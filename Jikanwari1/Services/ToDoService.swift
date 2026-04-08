import Foundation
import SwiftData

class ToDoService {
    private var context: ModelContext
    private var calendar = Calendar.current
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - ToDoRule (繰り返しルール) の操作
    
    /// 特定の教科に対する繰り返しルールを作成し、未来のLessonにタスクを一括生成する
    func createToDoRule(subject: Subject, title: String, relativeDay: Int, timeMode: TimeMode, offsetMinutes: Int? = nil, specificTimeHour: Int? = nil, specificTimeMinute: Int? = nil) throws {
        
        let newRule = ToDoRule(
            title: title,
            subject: subject,
            relativeDay: relativeDay,
            timeMode: timeMode,
            offsetMinutes: offsetMinutes,
            specificTimeHour: specificTimeHour,
            specificTimeMinute: specificTimeMinute
        )
        context.insert(newRule)
        
        // この教科に紐づく未来のLessonを取得して、このルールに基づくToDoを一括生成
        let now = Date()
        let futureLessons = subject.lessons.filter { $0.date >= now }
        
        for lesson in futureLessons {
            generateRoutineToDos(for: lesson, rules: [newRule])
        }
        
        try context.save()
    }
    
    /// 特定の教科に紐づくToDo生成ルール一覧を取得する
    func fetchToDoRules(for subject: Subject) -> [ToDoRule] {
        return subject.todoRules
    }
    
    /// ルールを更新し、未完了の既存ToDoの期限（deadLine）を再計算して上書きする
    func updateToDoRule(rule: ToDoRule, title: String, relativeDay: Int, timeMode: TimeMode, offsetMinutes: Int?, specificTimeHour: Int?, specificTimeMinute: Int?) throws {
        
        rule.title = title
        rule.relativeDay = relativeDay
        rule.timeMode = timeMode
        rule.offsetMinutes = offsetMinutes
        rule.specificTimeHour = specificTimeHour
        rule.specificTimeMinute = specificTimeMinute
        
        // このルールから生成された未完了のToDoを検索して再計算
        let incompleteToDos = rule.generatedToDos.filter { !$0.isCompleted }
        
        for todo in incompleteToDos {
            guard let lesson = todo.lesson else { continue }
            todo.title = title
            todo.deadLine = calculateDeadline(lesson: lesson, rule: rule)
        }
        
        try context.save()
    }
    
    /// ルールを削除する（Nullify設定により、既存のToDoはsourceRuleを失うが履歴として残る）
    func deleteToDoRule(rule: ToDoRule) throws {
        context.delete(rule)
        try context.save()
    }
    
    
    // MARK: - ToDo (タスク) の生成・操作
    
    /// 【内部処理用】Lessonとルールの情報からToDoインスタンスを生成する
    func generateRoutineToDos(for lesson: Lesson, rules: [ToDoRule]) {
        for rule in rules {
            let deadline = calculateDeadline(lesson: lesson, rule: rule)
            let newToDo = ToDo(title: rule.title, deadline: deadline, sourceRule: rule)
            
            newToDo.lesson = lesson
            newToDo.subject = rule.subject
            
            context.insert(newToDo)
        }
    }
    
    /// 単発のタスクを作成する
    func createIndependentToDo(title: String, deadline: Date, subject: Subject? = nil, lesson: Lesson? = nil) throws {
        let newToDo = ToDo(title: title, deadline: deadline, sourceRule: nil)
        newToDo.subject = subject
        newToDo.lesson = lesson
        
        context.insert(newToDo)
        try context.save()
    }
    
    /// 未完了のタスク一覧を期限の近い順（昇順）で取得する
    func fetchIncompleteToDos() throws -> [ToDo] {
        let predicate = #Predicate<ToDo> { todo in
            todo.isCompleted == false
        }
        let descriptor = FetchDescriptor<ToDo>(predicate: predicate, sortBy: [SortDescriptor(\.deadLine)])
        return try context.fetch(descriptor)
    }
    
    /// 指定したLesson、またはSubjectに関連するタスク一覧を取得する
    func fetchToDos(forSubject subject: Subject?, lesson: Lesson?) -> [ToDo] {
        // ※ SwiftUIのView側で表示しやすいように、リレーションから直接取得するアプローチ
        if let lesson = lesson {
            return lesson.toDos
        } else if let subject = subject {
            // 教科に紐づく全てのToDo（Lesson経由の繰り返しタスク ＋ 単発タスク）
            return subject.independentToDos + subject.todoRules.flatMap { $0.generatedToDos }
        }
        return []
    }
    
    /// 完了済みのタスク履歴を期限日時の降順（最近のものから）で取得する
    func fetchCompletedToDos() throws -> [ToDo] {
        let predicate = #Predicate<ToDo> { todo in
            todo.isCompleted == true
        }
        let descriptor = FetchDescriptor<ToDo>(predicate: predicate, sortBy: [SortDescriptor(\.deadLine, order: .reverse)])
        return try context.fetch(descriptor)
    }
    
    /// タスクの完了状態をトグルする
    func toggleToDoCompletion(todo: ToDo) throws {
        todo.isCompleted.toggle()
        try context.save()
    }
    
    /// タスクの詳細や期限を手動で更新する
    func updateToDoDetails(todo: ToDo, title: String, notes: String, deadline: Date) throws {
        todo.title = title
        todo.notes = notes
        todo.deadLine = deadline
        try context.save()
    }
    
    /// タスクを個別に削除する
    func deleteToDo(todo: ToDo) throws {
        context.delete(todo)
        try context.save()
    }
    
    
    // MARK: - Private Helpers
    
    /// Lessonの時刻情報とToDoRuleの条件から、具体的な期限(Date)を計算する
    private func calculateDeadline(lesson: Lesson, rule: ToDoRule) -> Date {
        // 1. 授業日をベースに、relativeDay（相対日）を加減算する
        // ※ relativeDay は「0」が当日、「-1」が前日、「1」が翌日を想定
        guard let targetDate = calendar.date(byAdding: .day, value: rule.relativeDay, to: lesson.date) else {
            return lesson.date // フォールバック
        }
        
        // 2. timeMode に応じて時間を設定する
        switch rule.timeMode {
        case .relativeToLesson:
            // 授業の開始時刻をセット
            guard let baseTime = calendar.date(bySettingHour: lesson.periodSnap.startHour,
                                               minute: lesson.periodSnap.startMinute,
                                               second: 0,
                                               of: targetDate) else { return targetDate }
            
            // offsetMinutes（オフセット分数）を加減算する
            // ※ offsetMinutes は「-30」なら授業開始30分前、「60」なら授業開始60分後を想定
            let offset = rule.offsetMinutes ?? 0
            return calendar.date(byAdding: .minute, value: offset, to: baseTime) ?? baseTime
            
        case .fixedTime:
            // 指定された固定時刻をセット
            let hour = rule.specificTimeHour ?? 23
            let minute = rule.specificTimeMinute ?? 59
            
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
        }
    }
}
