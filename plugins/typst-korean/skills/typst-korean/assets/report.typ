// main.typ에서 report와 source-note를 import한다. 사용 가능한 폰트를 전달한다.
#let report(
  title: "", author: none, date: none,
  fonts: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  cover: false, contents: false, body,
) = {
  set document(title: title, author: if author == none { () } else { author })
  set text(font: fonts, lang: "ko", region: "KR", size: 10.5pt)
  set page(
    paper: "a4", margin: (top: 24mm, bottom: 22mm, x: 22mm),
    header: align(right, text(size: 8pt, fill: rgb("#666666"), title)),
    footer: context align(center, text(size: 8pt, counter(page).display("1"))),
  )
  set par(leading: 0.65em, spacing: 0.8em, justify: true, first-line-indent: 0pt)
  set list(marker: [-], indent: 0.8em, body-indent: 0.5em)
  set heading(numbering: "I.1")
  show heading.where(level: 1): set text(size: 14pt, weight: "bold")
  show heading.where(level: 2): set text(size: 11.5pt, weight: "bold")
  set table(inset: 6pt, stroke: 0.4pt + rgb("#cccccc"))
  show figure.where(kind: table): set block(breakable: true)
  show figure.where(kind: table): set figure(supplement: [표])
  show figure.where(kind: image): set figure(supplement: [그림])
  if cover {
    page(header: none, footer: none)[
      #align(center + horizon)[
        #text(size: 24pt, weight: "bold", title)
        #v(1.5em)
        #if author != none { author }
        #if date != none { linebreak(); date }
      ]
    ]
  } else {
    text(size: 21pt, weight: "bold", title)
    if author != none or date != none {
      parbreak()
      text(size: 9pt, fill: rgb("#555555"))[
        #if author != none { author }
        #if author != none and date != none { " / " }
        #if date != none { date }
      ]
    }
    v(0.6em)
  }
  if contents {
    outline(title: [목차], indent: auto)
    pagebreak(weak: true)
  }
  body
}
#let source-note(body) = block(above: 0.35em, below: 0.8em)[
  #text(size: 8.5pt, fill: rgb("#555555"))[출처: #body]
]
