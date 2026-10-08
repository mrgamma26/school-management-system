# Domain and application models

This focused class diagram includes persisted-facing DTOs and the main auth state. It deliberately omits widgets. Sources: model files under [`lib/features`](../../lib/features/) and assessment repositories.

```mermaid
classDiagram
  class AuthState {
    AppUser user
    bool isLoading
    String errorMessage
  }
  class AppUser {
    String userId
    String username
    String roleId
    String roleName
    bool mustChangePassword
    bool isActive
  }
  class AcademicYear {
    String id
    int year
    String term
    String form
    DateTime startDate
    DateTime endDate
  }
  class ClassModel {
    String classId
    String classroomName
    String form
  }
  class Subject {
    String subjectId
    String subjectName
    String description
  }
  class ClassSubject {
    String id
    String classId
    String subjectId
    String staffId
    String academicYearId
  }
  class Student {
    String studentId
    String firstName
    String lastName
    String enrollmentStatus
  }
  class Guardian {
    String guardianId
    String userId
    String email
  }
  class Staff {
    String staffId
    String userId
    String employeeNumber
    String email
  }
  class Assessment {
    String assessmentId
    String classSubjectId
    String name
    String type
    double maxScore
  }
  class Grade {
    String gradeId
    String assessmentId
    String studentId
    double score
    String gradeStatus
  }
  class FeeStructure {
    String id
    String academicYearId
    String feeType
    double amount
  }
  class Payment {
    String id
    String studentId
    String feeStructureId
    double amount
    String method
    String receiptNumber
  }
  class PaymentChannel {
    String id
    String channelType
    String displayName
    bool isActive
  }
  AuthState --> AppUser
  ClassSubject --> AcademicYear
  ClassSubject --> ClassModel
  ClassSubject --> Subject
  ClassSubject --> Staff
  Assessment --> ClassSubject
  Grade --> Assessment
  Grade --> Student
  Payment --> Student
  Payment --> FeeStructure
  Payment --> PaymentChannel
  Guardian "many" -- "many" Student : linked through studentguardian
```

Progression, weeding, audit, and several report payloads are currently `Map<String,dynamic>` rather than named Dart models; their class relationships are therefore not invented here.
