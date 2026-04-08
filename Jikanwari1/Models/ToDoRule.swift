
import Foundation
import SwiftData

enum TimeMode: String, Codable {
    case relativeToLesson
    case fixedTime
}

@Model
class ToDoRule {
    var title: String
    // 繰り返しパターンを規定するための4項目。
    // relativeDayは、例えば「授業の3日前」とか「授業の当日」とかを表す。
    // timeModeは、relativeToLessonなら、授業からの相対時間offsetMinutesで期限が決まる。fixedTimeなら、specificTimeで期限が決まる。
    // offsetMinutesは、relativeToLessonの場合に、授業から何分前かを表す。
    // specificTimeは、timeModeがfixedTimeの場合の期限日時。（時と分で指定）
    var relativeDay: Int
    var timeMode: TimeMode
    var offsetMinutes: Int?
    var specificTimeHour: Int?
    var specificTimeMinute: Int?
    
    // 必ずSubjectに紐づく（ToDoRuleは、教科（Subject）の持ち物である。）
    var subject: Subject

    // このルールから生成されたToDoたち。ルールが削除されると、sourceRuleを持っている（＝繰り返しタスク）ToDoが、この所属を失う。
    @Relationship(deleteRule: .nullify, inverse: \ToDo.sourceRule) 
    var generatedToDos: [ToDo] = []
    
    init(title: String,subject: Subject, relativeDay: Int, timeMode: TimeMode = .relativeToLesson, offsetMinutes: Int? = nil, specificTimeHour: Int? = nil, specificTimeMinute: Int? = nil) {
        self.title = title
        self.subject = subject
        self.relativeDay = relativeDay
        self.timeMode = timeMode
        self.offsetMinutes = offsetMinutes
        self.specificTimeHour = specificTimeHour
        self.specificTimeMinute = specificTimeMinute
    }
}

