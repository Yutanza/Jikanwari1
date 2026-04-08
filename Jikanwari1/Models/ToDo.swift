import Foundation
import SwiftData


//繰り返しToDoと単発ToDo、両方を管理する
@Model
class ToDo {
    var title: String
    var isCompleted: Bool = false
    var notes: String = ""
    
    // 締め切り日時。繰り返しToDoの場合は、生成時にsourceRuleをもとに自動計算して保存する。
    // ただし、ユーザーが締め切りを編集する場合は、ここを再保存して対応できる。
    var deadLine: Date

    // 繰り返しパターンToDoの場合は、その繰り返しのルールを持つ
    var sourceRule: ToDoRule? 
    
    // ToDoは、lessonかSubjectいずれかに紐づく。繰り返しToDoならlessonに、単発ToDoなら両方ありうる。
    // それぞれの管理場所は、
    // →LessonならLesson.toDos
    // →SubjectならSubject.independentToDos
    var lesson: Lesson?
    var subject: Subject?
    
    init(title:String,deadline:Date, sourceRule: ToDoRule? = nil) {
        self.title = title
        self.deadLine = deadline
        self.sourceRule = sourceRule
    }


    
    
}
