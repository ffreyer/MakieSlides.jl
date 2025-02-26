# Note: All implementation details of @Layoutables are spread across three files within Makie.
# We have combined those details into one file here.


# from src/makielayout/types.jl
@Layoutable FormattedList


# from Makie/src/makielayout/default_attributes.jl
function default_attributes(::Type{FormattedList}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The displayed markdown list."
        md_list = md"""
            - item 1
            - item 2
            - item 3
        """
        "Controls if the text is visible."
        visible = true
        "The color of the text."
        color = lift_parent_attribute(scene, :textcolor, :black)
        "The font size of the text."
        textsize = lift_parent_attribute(scene, :fontsize, 16f0)
        "The font family of the text."
        font = lift_parent_attribute(scene, :font, "DejaVu Sans")
        "The justification of the text (:left, :right, :center)."
        justification = :left
        "The lineheight multiplier for the text."
        lineheight = 1.0
        "The vertical alignment of the text in its suggested boundingbox"
        valign = :top
        "The horizontal alignment of the text in its suggested boundingbox"
        halign = :left
        "The counterclockwise rotation of the text in radians."
        rotation = 0f0
        "The extra space added to the sides of the text boundingbox."
        padding = (0f0, 0f0, 0f0, 0f0)
        "The height setting of the text."
        height = Auto()
        "The width setting of the text."
        width = Auto()
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = false
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The align mode of the text in its parent GridLayout."
        alignmode = Inside()
        "Controls if the background is visible."
        backgroundvisible = true
        "The color of the background. "
        backgroundcolor = RGBf(0.9, 0.9, 0.9)
        "The line width of the rectangle's border."
        strokewidth = 1f0
        "Controls if the border of the rectangle is visible."
        strokevisible = true
        "The color of the border."
        strokecolor = RGBf(0, 0, 0)
        "The @printf pattern to format enumeration items"
        enumeration_pattern = "%i)"
        "The symbol for itemization items"
        itemization_symbol = "*"
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end


@doc """
FormattedList has the following attributes:

$(let
    _, docs, defaults = default_attributes(FormattedList, nothing)
    docvarstring(docs, defaults)
end)
"""
FormattedList


function layoutable(::Type{FormattedList}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)
    default_attrs = default_attributes(FormattedList, topscene).attributes
    theme_attrs = subtheme(topscene, :FormattedList)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (md_list, textsize, font, color, visible, halign, valign,
                    rotation, padding, strokecolor, strokewidth, strokevisible,
                    backgroundcolor, backgroundvisible, tellwidth, tellheight,
                    enumeration_pattern, itemization_symbol)

    layoutobservables = LayoutObservables(attrs.width, attrs.height, attrs.tellwidth, 
        attrs.tellheight, halign, valign, attrs.alignmode; suggestedbbox = bbox)

    strokecolor_with_visibility = lift(strokecolor, strokevisible) do col, vis
        vis ? col : RGBAf(0, 0, 0, 0)
    end

    item_symbol = itemization_symbol[]
    # bullet_match = match(r"^\s*(\*|\+|-)", item_symbol)
    # item_symbol = if !isnothing(bullet_match)
    #     # escape bullet for Markdown.parse
    #     offset = bullet_match.offset
    #     string(item_symbol[1:offset-1], '\\', item_symbol[offset:end])
    # end

    list = md_list[].content[]
    items, ordered = list.items, list.ordered
    symbol = if ordered < 0
        i -> item_symbol
    else
        format_enum_pttrn = Printf.Format(enumeration_pattern[])
        i -> Printf.format(format_enum_pttrn, i+ordered-1)
    end

    n_items = length(items)
    gridlayout = GridLayout(n_items+1, 2) # + 1 for fill box at the end
    symbol_labels = Label[]
    for (idx, item) in enumerate(items)
        # fmtlbl = FormattedLabel(fig_or_scene, text=symbol(idx), halign=:left, valign=:top)
        # using Label for now, because FormattedLabel promotes strings to Markdown.MD and
        # symbols like "1." would be parsed as Markdown.Lists, but the underlyinig 
        # formattedtext only works with Markdown.Paragraphs
        lbl = Label(fig_or_scene, text=symbol(idx), halign=:left, valign=:top)
        push!(symbol_labels, lbl)
        gridlayout[idx, 1] = lbl
        gridlayout[idx, 2] = FormattedLabel(fig_or_scene, text=first(item),
                                            halign=:left, valign=:top, tellwidth=false)
    end

    label_fillbox = Box(fig_or_scene, width=Fixed(1000.0 #= will be adjusted below=#))
    text_fillbox  = Box(fig_or_scene)
    gridlayout[end, 1] = label_fillbox
    gridlayout[end, 2] = text_fillbox

    # fix width of label_fillbox to maximum width of list symbols
    on(label_fillbox.layoutobservables.computedbbox) do bbox
        current_w = label_fillbox.width[].x
        max_w = 0.0
        for lbl in symbol_labels
            textbb = Rect2f(boundingbox(lbl.elements[:text]))
            tw = width(textbb)
            if max_w < tw; max_w = tw; end
        end
        if max_w != current_w
            label_fillbox.width[] = Fixed(max_w)
        end
    end

    label_fillbox.layoutobservables.suggestedbbox[] = 
        label_fillbox.layoutobservables.suggestedbbox[]

    rowgap!(gridlayout, 5)
    colgap!(gridlayout, 5)

    FormattedList(fig_or_scene, layoutobservables, attrs, Dict(:gridlayout => gridlayout))
end


function Base.setindex!(gp::GridPosition, fmtlist::FormattedList)
    gp.layout[gp.span.rows, gp.span.cols, gp.side] = fmtlist.elements[:gridlayout]
end


function Base.setindex!(fig::Figure, fmtlist::FormattedList, rows, cols, side = GridLayoutBase.Inner())
    fig.layout[rows, cols, side] = fmtlist.elements[:gridlayout]
    fmtlist
end
