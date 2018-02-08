'**
'** Example: Edit a Label size and color with BrightScript
'**

function init()
    m.top.backgroundURI = "pkg:/images/rsgde_bg_hd.jpg"
    m.myLabel = m.top.findNode("myLabel")
    example = m.top.findNode("exampleButtonGroup")
    example.buttons = [ "OK", "Cancel" ]
    examplerect = example.boundingRect()
    centerx = (1280 - examplerect.width) / 2
    centery = (720 - examplerect.height) / 2
    example.translation = [ centerx, centery ]

    'Set the font size
    m.myLabel.font.size=92

    'Set the color to light blue
    m.myLabel.color="0xFF0000FF"
    m.top.setFocus(true)
  '**
  '** The full list of editable attributes can be located at:
  '** http://sdkdocs.roku.com/display/sdkdoc/Label#Label-Fields
  '**
end function
