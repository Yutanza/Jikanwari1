import Foundation
import SwiftData

enum Attendance: String, Codable, CaseIterable {
    case present = "出席"
    case absent = "欠席"
    case late = "遅刻"
    case authorizedAbsence = "公欠"
}


struct PeriodSnap : Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
}

@Model
class Lesson {
    // 日付のみ
    var date: Date
    // // 開始時刻、終了時刻（Lesson生成時に保存する。なお、途中で時限設定の変更が行われた場合、ここを再保存する必要がある）
    var periodSnap: PeriodSnap

    var period: PeriodSetting // 時限（→時限のない授業なんて存在しない）
    var room: String?
    var teacher:String?
    // 出欠
    var attendance: Attendance?
    
    var note: String=""

    // 休講かどうか
    var isCancelled: Bool=false
    // 補講かどうか
    var isExtra: Bool=false

    // ユーザーが教室(room)を編集したかどうか（「教室変更」などでユーザーに通知するため）
    var isManuallyRoomEdited: Bool = false
    

    var subject: Subject?
    var sourceSchedule: SubjectSchedule?
    // 
    var timetable: Timetable?

    // このLessonに紐づくすべてのToDo（単発・ルーティーン両方を含む） →このLesson削除で道連れだが、休講フラグがあるので、すぐには道連れにならない。寛容な設計となっている。
    @Relationship(deleteRule: .cascade, inverse: \ToDo.lesson) 
    var toDos: [ToDo] = []

    // 単発授業など、ルーティーンでない授業の生成に使うイニシャライザ。 
    init(date:Date, period: PeriodSetting, subject: Subject?, room: String? = nil, teacher: String? = nil, attendance: Attendance? = nil) {
        self.date = date
        // PeriodSettingから現在の設定を「スナップショット」としてコピー
        self.periodSnap = PeriodSnap(
            startHour: period.startHour ?? 0,
            startMinute: period.startMinute ?? 0,
            endHour: period.endHour ?? 0,
            endMinute: period.endMinute ?? 0
        )
        self.period = period
        self.subject = subject
        self.teacher = teacher ?? subject?.teacher
        self.room = room ?? subject?.room 
        self.attendance = attendance

    }


    // 毎週の時間割に入っている、繰り返しパターンのある授業の生成に使うイニシャライザ。
    init(date: Date, subject: Subject, sourceSchedule: SubjectSchedule) {
        self.date = date
        // PeriodSettingから現在の設定を「スナップショット」としてコピー
        self.periodSnap = PeriodSnap(
            startHour: sourceSchedule.period.startHour ?? 0,
            startMinute: sourceSchedule.period.startMinute ?? 0,
            endHour: sourceSchedule.period.endHour ?? 0,
            endMinute: sourceSchedule.period.endMinute ?? 0
        )
        self.period = sourceSchedule.period 
        self.subject = subject
        self.sourceSchedule = sourceSchedule
        self.teacher = subject.teacher
        self.room = subject.room

    }
    
        
    
}
