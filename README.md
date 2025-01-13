![hypetype-preview-test](https://s13.gifyu.com/images/SXYU3.gif)

# Печатайте любые символы напрямую с клавиатуры

- функциональный аналог раскладки Бирмана
- с возможностью настройки символов через интерфейс
- без конфликтов со стандартными сочетаниями клавиш в других программах

[Скачать](https://github.com/Simbaruzz/hypetype/releases/download/v0.0.3/hypetype.exe) · [Глянуть обзор↗](https://youtu.be/dQw4w9WgXcQ)

<a href="https://youtu.be/dQw4w9WgXcQ" target="_blank">текст ссылки</a>
<br>

## Работает как обычно
Символы вводятся с нажатым правым Alt, например, Alt + < и Alt + > дадут «кавычки». Если символ нарисован в верхней части кнопки, значит нужно нажать ещё и Shift, например Alt + Shift + C поставит ¢. 


### Плюсы
- вставляет любые символы напрямую с клавиатуры
- позволяет настроить раскладку под свои задачи на лету
- работает с любой комбинированной диакритикой
- не требует подмены файлов и редактирования кода
- не зависит от текущей раскладки или языка ввода в системе
- не конфликтует с горячими клавишами Windows, Adobe, Figma и т.д.

### Минусы
- для установки требуются права администратора и перезагрузка
- правый Alt будет не совсем правый Alt — подробнее в FAQ
- только для Windows

<br>

## Установка и удаление
> [!IMPORTANT]
> Без активной галочки возле пункта «Виртуализация» программа работать не будет. Виртуализация включается и отключается только от имени Администратора. 

**Установка**
1. Скачиваем [hypetype.exe](https://github.com/Simbaruzz/hypetype/releases/download/v0.0.3/hypetype.exe) · 913 Кб
2. Сохраняем в папку, где программа будет лежать на постоянной основе
3. Запускаем hypetype.exe от имени Администратора и соглашаемся, что запускаем файл, скачанный из интернета
4. Кликаем правой клавишей мыши по иконке программы в трее (там где часики и дата), в открывшемся контекстном меню проставляем галочки на пунктах «✓Виртуализация» и «✓Запуск при старте».
5. Перезагружаемся
6. Пользуемся

 
**Удаление**
1. Идём в трей, нажимаем на пункт «Выход» в контекстном меню программы
2. Запускаем программу из папки, где она лежит, от имени Администратора
3. Снова идём в трей, кликаем по иконке программы, снимаем галочки с пунктов «Виртуализация» и «Запуск при старте»
4. Перезагружаемся

<br>

## Работа · фишки · особенности · _в разработке_
После включения «Виртуализации» и перезагрзуки, можно полноценно пользоваться. Не обязательно добавлять в автозапуск, можно запускать вручную, когда удобно. Но это вообще неудобно — проверено.

### Первый запуск
При первом запуске в папке с программой автоматически создается config.ini, в котором хранится стандартная карта символов. Если файл удалить, или перенести программу в другую папку без файла, то при следующем перезапуске программы будет создан новый с дефолтными значениями. 

### Настройка своей раскладки
Чтобы настроить под себя → кликаем по иконке правой кнопкой мыши, выбираем пункт меню «Редактировать». Откроется меню с программой. При клике на любую клавишу выйдет окно с двумя полями. Верхнее поле будет отвественно за символ, который вводится Alt+Shift, нижнее — для символов с Alt. В поля вставляем символ или даже символы, которые хотим вводить в будущем. Жмём сохранить.
> У — Удобненько! Настройки раскладки записываются напрямую в config.ini — его можно копировать, и переносить на другие устройства, заменять стандартный конфиг, тем самым — использоваться свою настроенную раскладку на другом компьютере.

### Работа с диакритикой
Сначала нажимаем комбинацию символа. Например, для гачека это будет комбинация Alt+Shift+V → запустится 5 секундный режим ожидания ввода символа → вводим нужный символ, например g → поставится ǧ. Ввод диакртики по двойному нажатию на символ с последующим «склеиванием» не является универсальным и очень чувствителен к программной среде ввода, поэтому переработан в пользу текущего способа. При желании можно вставлять свои диакртичесие знаки, главное использовать их комбинируемые версии из Unicode. 

### Эмодзи · каомодзи · комбинации символов
Да — будет работать. Выглядеть может максимально страшно >_< и криво, но работать будет. Эмодзи работают как лапочки 😎.
По аналогии с каомодзи можно придумать миллион способов для ввода комбинаций, которые требуются часто. Например, «пробел»+«интерпукнт»+«пробел» — удобный дивайдер, когда по смыслу запятая, точка или слеш не подходят.


<br>

## Частые вопросы и ответы · _в разработке_
**01 · Что такое Виртуализация и почему правый Alt теперь не совсем правый Alt?**
> Когда нажимается пункт меню «Виртуализация», программа идёт в реестр, создает файл, который говорит реестру обрабатывать нажатия на правый Alt как на другую клавишу — происходит замена значения клавиши на виртуальное. Именно поэтому не происходит конфликтов с хоткеями, использующих Alt или Ctrl+Alt.

**02 · Правый Alt теперь вообще нельзя использовать нигде?**
> Концептуально да — только для ввода символов. Однако, сочетание Alt+Enter предусмотрительно добавлено и работает как обычно. Необходимость использовать правый Alt вне других сочетаний автором испытана не была примерно никогда. Код открытый — всегда можно дописать, ежели что.

**03 · Кто разработчик, на чем написано, почему Windows ругается при первом запуке и безопасна ли эта программа?**
> Идея и разработка [by Simbarus↗](https://www.simbarus.com/)	 реализовано на AutoHotKey. Пакет не подписан сертификатом разработчика, однако, исходный код открытый, а сборка происходит на самом Github.

**04 · Сколько стоит?**
> По логике автора — каждый решает самостоятельно. Программа распространяется по модели Donationware: хочешь — поддерживаешь, не хочешь — не поддерживаешь. [Поддержать↗](https://boosty.to/simbarus/donate)



