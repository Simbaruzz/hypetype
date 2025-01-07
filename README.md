# hypetype

### Программа для удобной вставки любых символов напрямую с клавиатуры

- функциональный аналог раскладки Бирмана
- с возможностью настройки символов через интерфейс
- без конфликтов со стандартными сочетаниями клавиш в других программах

<br>

## Работает как обычно
Символы вводятся с нажатым правым Alt, например, Alt + < и Alt + > дадут «кавычки». Если символ нарисован в верхней части кнопки, значит нужно нажать ещё и Shift, например Alt + Shift + C поставит ¢. 

### Плюсы
- вставляет любые символы напрямую с клавиатуры
- позволяет настроить символы под свои задачи
- не требует подмены файлов и редактирования кода
- не зависит от текущей раскладки и языка ввода в системе
- не конфликтует с горячими клавишами Windows и других программ

### Минусы
- при первом запуске и удалении потребуются права администратора на редактирование реестра и перезагрузка
- правый Alt будет не совсем правый Alt (подробнее в FAQ)
- только для Windows

<br>

## Установка и удаление

> Важно! Без активной галочки возле пункта Виртуализация программа работать не будет. Виртуализация включается и отключается только от имени Администратора. Права требуются при первом запуске или удалении — всё остальное время программой можно пользоваться в обычном режиме.

Установка:
1. Скачиваем hypetype.exe
2. Сохраняем в папку, где программа будет лежать на постоянной основе
3. Запускаем от имени Администратора и соглашаемся, что запускаем файл, скачанный из интернета
4. Идём в трей, кликаем по иконке программы, ставим галочки на пунктах Виртуализация и Запуск при старте
5. Перезагружаемся
6. Пользуемся

Удаление:
1. Идём в трей, нажимаем на пункт Выход в контекстном меню программы
2. Запускаем программу из папки, где она лежит, от имени Администратора
3. Идём в трей, кликаем по иконке программы, снимаем галочки с пунктов Виртуализация и Запуск при старте
4. Перезагружаемся

<br>

## Работа с раскладкой
> При первом запуске в папке с программой создается config.ini, в котором хранятся настройки и символы пользователя. Если файл удалить, то при следующем перезапуске программы будет создан новый с дефолтными значениями. Свой настроенный конфиг можно копировать в другие системы, класть в папку с программой и пользоваться своей раскладкой на другом компьютере или ноутбуке.

Редактирование и сохранение символов...
Readme в разработке...

<br>

## Частые вопросы и ответы
Что такое Виртуализация и почему правый Alt теперь не совсем правый Alt?
> Когда нажимается пункт меню Виртуализация, программа идёт в реестр и говорит ему обрабатывать нажатия на правый Alt как на другую клавишу — происходит замена значения клавиши на виртуальное. Именно поэтому не происходит конфликтов с хоткеями и т.д.
