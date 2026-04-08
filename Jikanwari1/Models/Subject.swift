import Foundation
import SwiftData

@Model
class Subject {
    var title: String
    var teacher: String
    var room: String
    
    // 複数の時限設定が可能 （このSubjectが消されると道連れ消去）
    @Relationship(deleteRule: .cascade, inverse: \SubjectSchedule.sourceSubject)
    var schedules: [SubjectSchedule] = []

    
    @Relationship(deleteRule: .cascade, inverse: \Lesson.subject) var lessons: [Lesson] = []
    // ToDoRuleは、教科（Subject）と紐づいている。
    @Relationship(deleteRule: .cascade, inverse: \ToDoRule.subject) var todoRules: [ToDoRule] = []
    // この教科に直接紐づいたToDo (例えば「期末テスト」とか)
    @Relationship(deleteRule: .cascade, inverse: \ToDo.subject) var independentToDos: [ToDo] = []
    
    init(title: String, teacher: String = "", room: String = "") {
        self.title = title
        self.teacher = teacher
        self.room = room
    }
}
