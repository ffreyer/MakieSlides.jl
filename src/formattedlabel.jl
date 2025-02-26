# Note: All implementation details of @Layoutables are spread across three files within Makie.
# We have combined those details into one file here.


# from src/makielayout/types.jl
@Layoutable FormattedLabel


# from Makie/src/makielayout/default_attributes.jl
function default_attributes(::Type{FormattedLabel}, scene)
    attrs, docdict, defaultdict = @documented_attributes begin
        "The displayed text string."
        text = "Text"
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
        valign = :center
        "The horizontal alignment of the text in its suggested boundingbox"
        halign = :center
        "The counterclockwise rotation of the text in radians."
        rotation = 0f0
        "The extra space added to the sides of the text boundingbox."
        padding = (0f0, 0f0, 0f0, 0f0)
        "The height setting of the text."
        height = Auto()
        "The width setting of the text."
        width = Auto()
        "Controls if the parent layout can adjust to this element's width"
        tellwidth = true
        "Controls if the parent layout can adjust to this element's height"
        tellheight = true
        "The align mode of the text in its parent GridLayout."
        alignmode = Inside()
        "Controls if the background is visible."
        backgroundvisible = false
        "The color of the background. "
        backgroundcolor = RGBf(0.9, 0.9, 0.9)
        "The line width of the rectangle's border."
        strokewidth = 1f0
        "Controls if the border of the rectangle is visible."
        strokevisible = true
        "The color of the border."
        strokecolor = RGBf(0, 0, 0)
    end
    (attributes = attrs, documentation = docdict, defaults = defaultdict)
end


@doc """
FormattedLabel has the following attributes:

$(let
    _, docs, defaults = default_attributes(FormattedLabel, nothing)
    docvarstring(docs, defaults)
end)
"""
FormattedLabel


# from Makie/src/makielayout/layoutables/label.jl
function layoutable(::Type{FormattedLabel}, fig_or_scene, text; kwargs...)
    layoutable(FormattedLabel, fig_or_scene; text = text, kwargs...)
end


function layoutable(::Type{FormattedLabel}, fig_or_scene; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)
    default_attrs = default_attributes(FormattedLabel, topscene).attributes
    theme_attrs = subtheme(topscene, :FormattedLabel)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (text, textsize, font, color, visible, halign, valign,
                    rotation, padding, strokecolor, strokewidth, strokevisible,
                    backgroundcolor, backgroundvisible)

    layoutobservables = LayoutObservables(attrs.width, attrs.height, 
                                          attrs.tellwidth, attrs.tellheight, halign, valign, 
                                          attrs.alignmode; suggestedbbox = bbox)

    textpos = Observable(Point3f(0, 0, 0))

    # the text
    fmttxt = formattedtext!(topscene, text, position = textpos, textsize = textsize, 
        font = font, color = color, visible = visible, align = (:left, :top), 
        rotation = rotation, markerspace = :data, justification = attrs.justification,
        lineheight = attrs.lineheight, inspectable = false)

    onany(layoutobservables.computedbbox, padding, halign, valign) do bbox, padding, halign, valign

        textbb = Rect2f(boundingbox(fmttxt))
        tw, th = width(textbb), height(textbb)
        w, h = width(bbox), height(bbox)
        box, boy = bbox.origin

        # position text
        tx = box + padding[1]
        isnothing(tx) && error()
        tx += if halign === :right
            w
        elseif halign === :center
            0.5 * w
        elseif halign === :left
            0
        end
        ty = boy + padding[3]
        ty += if valign === :top
            h
        elseif valign === :center
            0.5 * h
        elseif valign === :bottom
            0
        end

        textpos[] = Point3f(tx, ty, 0)

        fmttxt.maxwidth[] = w
        if h != th
            layoutobservables.autosize[] = (nothing, th)
        end
    end

    # background box
    strokecolor_with_visibility = lift(strokecolor, strokevisible) do col, vis
        vis ? col : RGBAf(0, 0, 0, 0)
    end

    ibbox = lift(layoutobservables.computedbbox) do bbox
        ibbox = round_to_IRect2D(layoutobservables.suggestedbbox[])
    end

    bg = poly!(topscene, ibbox, color = backgroundcolor, visible = backgroundvisible,
               strokecolor = strokecolor_with_visibility, strokewidth = strokewidth,
               inspectable = false)
    translate!(bg, 0, 0, -10) # move behind text

    FormattedLabel(fig_or_scene, layoutobservables, attrs,
                   Dict(:formattedtext => fmttxt, :background => bg))
end
