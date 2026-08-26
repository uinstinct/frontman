/**
 * UserMessage - Renders user messages (text, images, files, annotations)
 *
 * Displays user messages in a purple/violet bubble style.
 * Images render as thumbnails with lightbox preview.
 * Annotations render as compact chips with numbered badges.
 */
module UserContentPart = Client__State__Types.UserContentPart
module MessageAnnotation = Client__Message.MessageAnnotation
module AgentChip = Client__AgentChip

let _circledNumbers = [
  "\u{2460}",
  "\u{2461}",
  "\u{2462}",
  "\u{2463}",
  "\u{2464}",
  "\u{2465}",
  "\u{2466}",
  "\u{2467}",
  "\u{2468}",
  "\u{2469}",
  "\u{246A}",
  "\u{246B}",
  "\u{246C}",
  "\u{246D}",
  "\u{246E}",
  "\u{246F}",
  "\u{2470}",
  "\u{2471}",
  "\u{2472}",
  "\u{2473}",
]

let _getBadge = (index: int): string =>
  _circledNumbers->Array.get(index)->Option.getOr(Int.toString(index + 1))

@react.component
let make = (
  ~content: array<UserContentPart.t>,
  ~annotations: array<MessageAnnotation.t>=[],
  ~messageId: string,
  ~agent: Client__Agent.t,
  ~isNew: bool=false,
  ~onEdit: option<(string, result<unit, string> => unit) => unit>=?,
  ~removedMessageCount: int=0,
) => {
  let rootClass = isNew
    ? "frontman-content-auto animate-in fade-in duration-100"
    : "frontman-content-auto"
  let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)
  let highlightedAnnotation = Client__State.useSelector(
    Client__State.Selectors.highlightedAnnotation,
  )

  let imageParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.Image({image, mediaType, name: _, id: _}) => Some((image, mediaType))
    | _ => None
    }
  )
  let textParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.Text({text}) => Some(text)
    | _ => None
    }
  )
  let fileParts = content->Array.filterMap(part =>
    switch part {
    | UserContentPart.File({file}) => Some(file)
    | _ => None
    }
  )

  let hasAnnotations = Array.length(annotations) > 0

  let originalText = textParts->Array.join("\n\n")
  let (editDraft, setEditDraft) = React.useState((): option<string> => None)
  let (isSaving, setIsSaving) = React.useState(() => false)
  let (editError, setEditError) = React.useState((): option<string> => None)

  let cancelEdit = () => {
    setEditDraft(_ => None)
    setIsSaving(_ => false)
    setEditError(_ => None)
  }

  // Saving is sending: on success the whole transcript reloads and this component is
  // rebuilt, so only the failure path has to restore the editor.
  let saveEdit = (draft: string) => {
    let trimmed = draft->String.trim
    switch (trimmed == "", trimmed == originalText->String.trim, onEdit) {
    | (true, _, _) => ()
    | (false, true, _) => cancelEdit()
    | (false, false, None) => ()
    | (false, false, Some(onEdit)) =>
      setIsSaving(_ => true)
      setEditError(_ => None)
      onEdit(draft, result =>
        switch result {
        | Ok() => ()
        | Error(error) =>
          setIsSaving(_ => false)
          setEditError(_ => Some(error))
        }
      )
    }
  }

  let draftRowCount = (draft: string) =>
    switch Array.length(draft->String.split("\n")) {
    | lines if lines < 2 => 2
    | lines if lines > 12 => 12
    | lines => lines
    }

  let handleEditKeyDown = (draft: string, e: ReactEvent.Keyboard.t) =>
    switch (ReactEvent.Keyboard.key(e), ReactEvent.Keyboard.shiftKey(e)) {
    | ("Enter", false) =>
      ReactEvent.Keyboard.preventDefault(e)
      saveEdit(draft)
    | ("Escape", _) =>
      ReactEvent.Keyboard.preventDefault(e)
      cancelEdit()
    | _ => ()
    }

  <div className=rootClass>
    <div
      className="group/user-message relative mt-2.5 w-full min-w-0 bg-violet-600/80 rounded-2xl px-3 pb-2 pt-5 text-[14px] leading-relaxed text-white font-semibold"
    >
      <div className="absolute -top-2.5 left-1 z-10">
        <AgentChip agent className="" borderColor="rgb(124 58 237 / 0.8)" />
      </div>
      {hasAnnotations
        ? <div className="flex flex-wrap gap-1.5 mb-2 min-w-0 w-full">
            {annotations
            ->Array.mapWithIndex((annotation, i) => {
              let badge = _getBadge(i)
              let label = switch annotation.cssClasses {
              | Some(classes) =>
                let firstClass = classes->String.split(" ")->Array.get(0)->Option.getOr("")
                firstClass->String.length > 0
                  ? `<${annotation.tagName}.${firstClass}>`
                  : `<${annotation.tagName}>`
              | None => `<${annotation.tagName}>`
              }
              let selector = switch annotation.selector {
              | Ok(Some(selector)) => Some(selector)
              | Ok(None) | Error(_) => None
              }
              let isHighlighted = switch highlightedAnnotation {
              | Some(highlighted) => highlighted.annotationId == annotation.id
              | None => false
              }
              let baseChipClass = "flex items-center gap-1 px-2 py-0.5 rounded-md min-w-0 w-full text-xs font-mono text-left disabled:cursor-default"
              let chipClass = switch (selector, isHighlighted) {
              | (Some(_), true) =>
                `${baseChipClass} bg-violet-400/80 text-white cursor-pointer ring-1 ring-white/70 transition-colors`
              | (Some(_), false) =>
                `${baseChipClass} bg-violet-500/60 text-violet-100 cursor-pointer hover:bg-violet-400/70 transition-colors`
              | (None, _) => `${baseChipClass} bg-violet-500/60 text-violet-100`
              }
              let chipTitle = switch selector {
              | Some(_) => "Click to highlight in preview"
              | None => "No selector captured for this element"
              }

              <div
                key={`${messageId}-ann-${Int.toString(i)}`}
                className="flex flex-col gap-0.5 min-w-0 w-full"
              >
                <button
                  type_="button"
                  className=chipClass
                  title=chipTitle
                  disabled={selector->Option.isNone}
                  ariaPressed={isHighlighted ? #"true" : #"false"}
                  onClick={_ =>
                    switch selector {
                    | Some(selector) =>
                      Client__State.Actions.highlightAnnotation(
                        ~annotationId=annotation.id,
                        ~selector,
                      )
                    | None => ()
                    }}
                >
                  <span className="text-violet-200 shrink-0"> {React.string(badge)} </span>
                  <span className="truncate min-w-0 flex-1"> {React.string(label)} </span>
                </button>
                {switch annotation.comment {
                | Some(comment) =>
                  <div className="text-[11px] text-violet-200/80 italic pl-1 w-full truncate">
                    {React.string(comment)}
                  </div>
                | None => React.null
                }}
              </div>
            })
            ->React.array}
          </div>
        : React.null}

      {Array.length(imageParts) > 0
        ? <div className="flex flex-wrap gap-2 mb-2">
            {imageParts
            ->Array.mapWithIndex(((src, _mediaType), i) => {
              let isImage = !(src->String.includes("application/pdf"))
              <div
                key={`${messageId}-img-${Int.toString(i)}`}
                className={`w-12 h-12 rounded-lg overflow-hidden border border-white/20
                           transition-colors ${isImage
                    ? "cursor-pointer hover:border-white/50"
                    : ""}`}
                onClick={_ => {
                  if isImage {
                    setPreviewSrc(_ => Some(src))
                  }
                }}
              >
                {isImage
                  ? <img
                      src
                      alt={`Attachment ${Int.toString(i + 1)}`}
                      className="w-full h-full object-cover"
                    />
                  : <div
                      className="w-full h-full flex items-center justify-center bg-violet-700/50 text-violet-200"
                    >
                      <Client__ToolIcons.FileIcon size=20 />
                    </div>}
              </div>
            })
            ->React.array}
          </div>
        : React.null}

      {Array.length(fileParts) > 0
        ? <div className="flex flex-wrap gap-1.5 mb-2">
            {fileParts
            ->Array.mapWithIndex((file, i) => {
              <div
                key={`${messageId}-file-${Int.toString(i)}`}
                className="flex items-center gap-1.5 px-2 py-1 rounded-md
                           bg-violet-700/50 text-violet-100 text-xs"
              >
                <Client__ToolIcons.FileIcon size=12 />
                <span className="truncate max-w-[120px]"> {React.string(file)} </span>
              </div>
            })
            ->React.array}
          </div>
        : React.null}

      {switch editDraft {
      | Some(draft) =>
        <div className="flex flex-col gap-2">
          <textarea
            autoFocus=true
            value={draft}
            disabled={isSaving}
            rows={draftRowCount(draft)}
            onChange={e => {
              let value = ReactEvent.Form.target(e)["value"]
              setEditDraft(_ => Some(value))
            }}
            onKeyDown={handleEditKeyDown(draft, ...)}
            className="w-full resize-y rounded-lg bg-violet-900/50 px-2 py-1.5 text-[14px]
                       font-normal text-white placeholder-violet-300
                       focus:outline-none focus:ring-1 focus:ring-white/50 disabled:opacity-60"
          />
          {switch removedMessageCount {
          | 0 => React.null
          | count =>
            <div className="text-[11px] font-normal text-violet-200/90">
              {React.string(
                `Saving removes ${count->Int.toString} later ${count == 1
                    ? "message"
                    : "messages"} and re-runs from here.`,
              )}
            </div>
          }}
          {switch editError {
          | Some(error) =>
            <div className="text-[11px] font-normal text-amber-200"> {React.string(error)} </div>
          | None => React.null
          }}
          <div className="flex items-center gap-2">
            <button
              type_="button"
              disabled={isSaving || draft->String.trim == ""}
              onClick={_ => saveEdit(draft)}
              className="rounded-md bg-white/20 px-2 py-0.5 text-xs font-semibold
                         hover:bg-white/30 disabled:opacity-40 disabled:hover:bg-white/20"
            >
              {React.string(isSaving ? "Saving..." : "Save")}
            </button>
            <button
              type_="button"
              disabled={isSaving}
              onClick={_ => cancelEdit()}
              className="rounded-md px-2 py-0.5 text-xs font-semibold text-violet-200
                         hover:text-white disabled:opacity-40"
            >
              {React.string("Cancel")}
            </button>
          </div>
        </div>
      | None =>
        <>
          {textParts
          ->Array.mapWithIndex((text, i) => {
            <div
              key={`${messageId}-text-${Int.toString(i)}`}
              className="whitespace-pre-wrap break-words"
            >
              {React.string(text)}
            </div>
          })
          ->React.array}
          {switch onEdit {
          | Some(_) =>
            <div className="flex justify-end">
              <button
                type_="button"
                title="Edit and re-run from this message"
                onClick={_ => {
                  setEditError(_ => None)
                  setEditDraft(_ => Some(originalText))
                }}
                className="text-[11px] font-normal text-violet-200/70 opacity-0
                           transition-opacity hover:text-white focus:opacity-100
                           group-hover/user-message:opacity-100"
              >
                {React.string("Edit")}
              </button>
            </div>
          | None => React.null
          }}
        </>
      }}
    </div>

    {switch previewSrc {
    | Some(src) => <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
    | None => React.null
    }}
  </div>
}
