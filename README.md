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
- Submit asks for confirmation and shows how many questions are unanswered

**Phase 3: results and analytics (done)**
- Results page after every paper: score and percentage, correct / wrong / skipped, time taken, marks by chapter
- Answer review: each question with the student's answer, the correct answer and the worked solution
- Subjective answers are marked by the student against the model solution, and the score updates
- My results dashboard: papers taken, average and best score, chapter accuracy across all papers (chapters below 60% called out), and every past paper
- Results are saved on the device for now; they move to the student's account once sign-in is added (premium advanced analytics will build on that)

**Phase 4: past-paper bank (in progress)**
- Questions from official CBSE board papers, each labelled with year, Q.P. code and question number, and credited to CBSE
- "Past papers only" option when creating a paper
- Added so far: CBSE Class 10 Mathematics (Standard), Q.P. 30/1/1 for 2022 (Term 2), 2023, 2024, 2025 and 2026: 196 questions. CBSE only publishes papers from 2022 onwards on its site, so earlier years need another official source

**Board-pattern papers**
- "Board pattern" (the default) builds a new random paper in the CBSE layout every time: Section A 20 × 1 (MCQ and assertion-reason), B 5 × 2, C 6 × 3, D 4 × 5, E 3 case studies × 4 = 80 marks, 3 hours
- Each section is filled at random from the bank; the two sides of an internal OR choice never appear together, and case studies stay whole (both 1-mark parts plus one 2-mark part)
- Questions a student has already had on earlier papers are used last, so each new paper is as fresh as the bank allows

Next phases: 3) results and analytics, 4) 10-year historical question bank, 5) practice mode, bookmarks, reattempts, printable papers and more.

## Question bank

`assets/question_bank/sample_questions.json` holds 36 **sample** questions (CBSE Class 10 Mathematics: Real Numbers, Polynomials, Quadratic Equations), written for testing. They are tagged `"source": "sample"` with no year, and the app labels them as not coming from real board papers. Past-paper questions come from the official papers CBSE publishes at cbse.gov.in and carry `"source": "past_paper"`, `year`, `paper` (Q.P. code) and `number`. Questions that need a figure or graph are left out for now. Solutions are written for this portal, not copied from CBSE marking schemes. Each bank file is listed in `QuestionBank.assetPaths`.

Each question is tagged with `board`, `grade`, `subject`, `chapter`, `type` (`mcq` / `subjective`), `difficulty` (`normal` / `tough`), `marks`, and optionally `year`.

## Run it

```bash
flutter pub get
flutter run -d chrome
flutter test
```
