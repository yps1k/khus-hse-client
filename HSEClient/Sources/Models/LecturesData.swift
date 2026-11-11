import Foundation

// Конспекты из канала «Маруся Конспектовна» (экспорт 11.11.2026).

struct Lecture: Identifiable { let id = UUID(); let subject: String; let icon: String; let number: Int; let topic: String; let date: String; let file: String }

let lectures: [Lecture] = [
    Lecture(subject: "Алгебра", icon: "function", number: 1, topic: "Матрицы. Операции над матрицами", date: "03.09.2026", file: "-01-0.pdf"),
    Lecture(subject: "Алгебра", icon: "function", number: 3, topic: "Новый дроп! Сегодня без опозданий", date: "16.09.2026", file: "-03-4.pdf"),
    Lecture(subject: "Алгебра", icon: "function", number: 4, topic: "Теорема Саррюса. Свойства определителя(1)", date: "24.09.2026", file: "-04-7.pdf"),
    Lecture(subject: "Алгебра", icon: "function", number: 5, topic: "Свойства определителя(2), дополняющий минор, алгебраическое дополнение, теорема", date: "01.10.2026", file: "-05-10.pdf"),
    Lecture(subject: "Алгебра", icon: "function", number: 6, topic: "Вычисление определителя. Правило Крамера. Обратная матрица. Союзная матрица. Выч", date: "12.10.2026", file: "-06-13.pdf"),
    Lecture(subject: "Алгебра", icon: "function", number: 7, topic: "Свойства ранга матрицы. Линейная зависимость строк. Критерий линейной зависимост", date: "16.10.2026", file: "-07-16.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 1, topic: "Формальная логика. Метод мат.индукции. Неравенство Бернулли.", date: "07.09.2026", file: "-01-1.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 2, topic: "Обратите внимание на примечания и обязательно просмотрите конспект до конца", date: "12.09.2026", file: "-02-3.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 3, topic: "Всем классного «экстра фестиваля»!!!", date: "18.09.2026", file: "-03-5.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 4, topic: "Бесконечно большие и бесконечно малые последовательности. Предельный переход в н", date: "27.09.2026", file: "-04-8.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 5, topic: "Теорема о двух милиционерах. Аксиома непрерывности. Супремум. Инфимум. Теорема В", date: "05.10.2026", file: "-05-11.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 6, topic: "Теорема Вейерштрасса. Критерий Коши. Фундаментальные последовательности и Критер", date: "14.10.2026", file: "-06-14.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 6, topic: "", date: "17.10.2026", file: "-06-18.pdf"),
    Lecture(subject: "Матанализ", icon: "sum", number: 8, topic: "Теорема о пределе сложной функции. Первый замечательный предел. Второй замечател", date: "29.10.2026", file: "-08-19.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 1, topic: "Высказывание. Совершенное число. Закон контропозиции. Логические формулы.", date: "07.09.2026", file: "-01-2.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 3, topic: "Причесала и докрутила лекцию по дискре. Я предлагаю сделать это отдельным видом", date: "20.09.2026", file: "-03-6.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 4, topic: "Прошу любить и жаловать 🤕🤕🤕", date: "27.09.2026", file: "-04-9.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 5, topic: "ПМИ. ПНЧ. ПСИ. Арифметика целых чисел.", date: "05.10.2026", file: "-05-12.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 6, topic: "Теорема о делении с остатком. Сравнение по модулю.", date: "14.10.2026", file: "-06-15.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 7, topic: "Основы арифметики и критерий делимости. Разложение на простые множители и показа", date: "17.10.2026", file: "-07-17.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 8, topic: "НОД. Тождество Безу. Взаимно простые числа.", date: "08.11.2026", file: "-08-20.pdf"),
    Lecture(subject: "Дискретная математика", icon: "number", number: 9, topic: "Тождество Безу. Функция Эйлера. Малая теорема Ферма.", date: "09.11.2026", file: "-09-21.pdf"),
]