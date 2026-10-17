# Exam Practice Portal

Practice exams for grades 8 to 12 (CBSE, ICSE and State Boards). Students pick a class, subject, chapters or the full syllabus, question type, difficulty and duration, and the app builds a paper from the tagged question bank.

Built with Flutter (web, Android and iOS from one codebase).

## Status

**Phase 1: paper generation (done)**
- Setup screen offering only the boards, classes, subjects and chapters that exist in the bank
- Generator that picks matching questions up to the usual marks for the chosen duration (30 min = 12, 1 hr = 25, 2 hr = 50, 3 hr = 80), shuffles MCQ options and orders questions by marks
- Tough papers use tough questions first and top up with normal ones; papers are flagged when the bank runs short

**Phase 2: timed exam (done)**
- Countdown timer that turns red in the last 5 minutes and submits automatically at zero
- One question at a time with previous / next, flag for review, and a question panel showing answered, unanswered and flagged questions (bottom sheet on phones, side panel on wide screens)
- Auto-save on the device after every change; an unfinished exam can be resumed after a refresh or closing the app (the timer keeps running)
- Submit asks for confirmation and shows how many questions are unanswered; MCQ papers show the score straight away

Next phases: 3) results and analytics, 4) 10-year historical question bank, 5) practice mode, bookmarks, reattempts, printable papers and more.

## Question bank

`assets/question_bank/sample_questions.json` holds 36 **sample** questions (CBSE Class 10 Mathematics: Real Numbers, Polynomials, Quadratic Equations), written for testing. They are tagged `"source": "sample"` with no year, and the app labels them as not coming from real board papers. Real past-paper questions will carry `"source": "past_paper"` and their `year`, and will be edited through the admin panel.

Each question is tagged with `board`, `grade`, `subject`, `chapter`, `type` (`mcq` / `subjective`), `difficulty` (`normal` / `tough`), `marks`, and optionally `year`.

## Run it

```bash
flutter pub get
flutter run -d chrome
flutter test
```
