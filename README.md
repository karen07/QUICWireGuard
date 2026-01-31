# QUICWireGuard

QUICWireGuard is a legacy Linux kernel patch that makes the initial WireGuard handshake resemble QUIC UDP traffic on port 443.

The patch does not implement QUIC and does not carry normal WireGuard data packets through a QUIC connection. It only prepends and removes a small QUIC-like header around WireGuard Handshake Initiation and Handshake Response packets while leaving the WireGuard protocol, Noise handshake, and cryptography unchanged.

The project was created in 2024 as a deliberately small traffic-obfuscation experiment. By 2026 its threat model is outdated: hiding only the fixed handshake signature is not enough against traffic classification that can use packet sizes, timing, direction, and other session-level features.

The repository is therefore kept for history, existing deployments, research, and as a compact example of modifying WireGuard directly in the Linux kernel. New deployments should use maintained alternatives such as AmneziaWG instead.

## Описание

QUICWireGuard - устаревший патч ядра Linux, который делает начальное рукопожатие WireGuard похожим на трафик QUIC по UDP на порту 443.

Патч не реализует QUIC и не передает обычные пакеты данных WireGuard через соединение QUIC. Он только добавляет и удаляет небольшой QUIC-подобный заголовок вокруг пакетов WireGuard Handshake Initiation и Handshake Response, оставляя без изменений сам протокол WireGuard, рукопожатие Noise и криптографию.

Проект был создан в 2024 году как намеренно небольшой эксперимент по маскировке трафика. К 2026 году его модель угроз устарела: скрытия только фиксированной сигнатуры рукопожатия недостаточно против классификации трафика, которая может учитывать размеры пакетов, временные характеристики, направление и другие признаки всей сессии.

Поэтому репозиторий сохраняется для истории, существующих установок, исследований и как компактный пример модификации WireGuard непосредственно в ядре Linux. Для новых установок следует использовать поддерживаемые альтернативы, например AmneziaWG.

## Статус проекта

> [!WARNING]
> QUICWireGuard является устаревшим проектом.
>
> Начиная с 2026 года практического смысла использовать его для новых установок уже нет.
>
> Репозиторий остается доступен для истории, существующих установок, исследований и как небольшой пример модификации WireGuard непосредственно в ядре Linux.

Для новых установок используйте [Amnezia](https://amnezia.org/) и AmneziaWG.

Моя актуальная реализация, пакеты и система сборки AmneziaWG для OpenWrt:

https://github.com/karen07/amneziawg-openwrt-package

Если задача заключается в построении полноценной сети или mesh-сети из OpenWrt-роутеров:

https://github.com/karen07/openwrt-mesh-builder

## Мотивация

QUICWireGuard появился в 2024 году как решение простой задачи.

WireGuard является компактным, быстрым и безопасным VPN-протоколом, однако его UDP handshake имеет фиксированную и легко узнаваемую структуру.

На тот момент одним из простых способов усложнить определение WireGuard было скрыть его характерный handshake за заголовком, похожим на распространенный UDP-протокол.

QUIC хорошо подходил для этой задачи, поскольку уже широко использовался поверх UDP, в частности на порту 443.

Идея QUICWireGuard была намеренно минималистичной:

```text
WireGuard handshake
        |
        v
Добавить QUIC-подобный заголовок
        |
        v
Отправить через UDP 443
```

Вместо дополнительного userspace proxy, еще одного туннеля или реализации полноценного транспортного протокола QUICWireGuard изменяет непосредственно WireGuard в ядре Linux.

При работе через UDP-порт 443 к пакетам WireGuard Handshake Initiation и Handshake Response добавляется небольшой QUIC-подобный заголовок.

На принимающей стороне этот заголовок удаляется, после чего пакет передается обычному коду WireGuard.

Сам протокол WireGuard, Noise handshake и криптография при этом не изменяются.

Целью проекта никогда не была реализация WireGuard поверх настоящего QUIC.

Задача была значительно проще:

```text
Сделать WireGuard handshake
менее похожим на WireGuard.
```

Для threat model 2024 года это был полезный и намеренно простой эксперимент.

## Как это работает

Патч добавляет небольшую структуру, похожую на начало QUIC Initial packet.

Она содержит поля:

```text
Flags
Version
DCID length
DCID
SCID length
SCID
Token length
Data length
```

Этот режим включается при использовании UDP-порта 443.

Например, в патче определены:

```c
#define QUIC_PORT 443
#define QUIC_FLAGS 0xC0
```

Для Handshake Initiation генерируется случайный DCID.

Для Handshake Response генерируется случайный SCID.

Схематично:

```text
Обычный WireGuard:

UDP
+-- WireGuard Handshake


QUICWireGuard:

UDP
+-- QUIC-подобный header
    +-- WireGuard Handshake
```

Дополнительный заголовок используется только для WireGuard handshake-пакетов, которые обрабатывает этот патч.

Обычные WireGuard data packets не передаются внутри QUIC.

## Это не настоящий QUIC

QUICWireGuard не реализует протокол QUIC.

В нем нет:

- транспорта QUIC
- QUIC streams
- congestion control QUIC
- TLS 1.3 протокола QUIC
- HTTP/3
- state machine QUIC
- передачи WireGuard внутри настоящего QUIC-соединения

Проект только делает начало WireGuard-соединения похожим на QUIC-трафик.

Это важное различие.

Пакет может выглядеть похожим на QUIC при простом анализе, не являясь при этом частью настоящего QUIC-соединения.

## Почему этот подход устарел к 2026 году

Главное изменение с 2024 года произошло не в самом WireGuard.

Изменился threat model.

QUICWireGuard создавался против относительно простого способа определения протокола:

```text
У WireGuard узнаваемый handshake
        |
        v
Изменяем внешний вид handshake
        |
        v
Простая сигнатура WireGuard больше не совпадает
```

Современному DPI уже не обязательно определять протокол только по фиксированной сигнатуре первых пакетов.

Для классификации может использоваться множество характеристик всей сессии:

- размеры пакетов
- последовательность пакетов
- направление пакетов
- интервалы между пакетами
- повторяемое поведение соединения
- статистические характеристики трафика

Поэтому маскировки только начального WireGuard handshake теперь недостаточно для противодействия современному анализу трафика.

Эволюция AmneziaWG хорошо показывает это изменение.

Ранние версии решали задачу удаления характерных сигнатур WireGuard и мимикрии под другие протоколы.

AmneziaWG 2.0 распространил обфускацию и на передачу данных, изменяя заголовки и размеры пакетов.

AmneziaWG 3.0 появился в ответ на массовые блокировки 2026 года, которые показали, что маскировки отдельных признаков трафика уже недостаточно. В нем изменяются размеры, последовательность и интервалы между пакетами, а также другие характеристики сессии, чтобы усложнить статистическую классификацию.

Актуальная документация AmneziaWG:

https://docs.amnezia.org/ru/documentation/amnezia-wg/

Эволюцию задачи можно представить так:

```text
2024

Фиксированная сигнатура WireGuard
        |
        v
Скрыть handshake
        |
        v
QUICWireGuard


2026

Классификация всей сессии
        |
        v
Одной маскировки handshake уже недостаточно
        |
        v
AmneziaWG
```

QUICWireGuard по-прежнему интересен как небольшой networking experiment и как пример того, как WireGuard можно модифицировать непосредственно внутри ядра Linux.

Но для новой установки, основной задачей которой является устойчивость к современному DPI и блокировкам VPN, этого подхода уже недостаточно.

## Современные альтернативы

### Amnezia

https://amnezia.org/

Для современных VPN-установок и работы в условиях блокировок используйте Amnezia и AmneziaWG.

### AmneziaWG для OpenWrt

https://github.com/karen07/amneziawg-openwrt-package

Это моя актуальная реализация, пакеты и система сборки AmneziaWG для OpenWrt.

Для новых VPN-установок на OpenWrt следует использовать этот проект вместо QUICWireGuard.

### OpenWrt Mesh Builder

https://github.com/karen07/openwrt-mesh-builder

Если задача заключается в построении и поддержке полноценной сети из нескольких OpenWrt-роутеров, используйте OpenWrt Mesh Builder.

Он решает более широкую задачу: построение всей сети, а не только маскировку одного WireGuard-туннеля.

## Статья

Исходная идея, мотивация и реализация подробно описаны в статье:

[WireGuard и QUIC](https://habr.com/ru/articles/867102/)

Статья была написана в 2024 году и описывает проект в том контексте, для которого он первоначально создавался.

Она остается основной технической и исторической документацией QUICWireGuard.

## Лицензия

GNU Affero General Public License v3.0.

See [LICENSE](LICENSE).
