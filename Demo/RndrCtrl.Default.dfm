inherited TDefaultLayerRenderingControl: TTDefaultLayerRenderingControl
  Height = 337
  ExplicitHeight = 337
  object BrushLabel: TLabel
    Left = 8
    Top = 160
    Width = 30
    Height = 15
    Caption = 'Brush'
  end
  object CoordinateSystemLabel: TLabel
    Left = 11
    Top = 282
    Width = 99
    Height = 15
    Caption = 'Coordinate system'
  end
  object OpacityLabel: TLabel
    Left = 8
    Top = 34
    Width = 41
    Height = 15
    Caption = 'Opacity'
  end
  object PenLabel: TLabel
    Left = 8
    Top = 82
    Width = 20
    Height = 15
    Caption = 'Pen'
  end
  object PointLabel: TLabel
    Left = 8
    Top = 235
    Width = 33
    Height = 15
    Caption = 'Points'
  end
  object BrushColorPanel: TPanel
    Left = 9
    Top = 176
    Width = 165
    Height = 26
    BevelOuter = bvLowered
    Color = clSkyBlue
    ParentBackground = False
    TabOrder = 0
    StyleElements = [seFont, seBorder]
    OnClick = BrushColorPanelClick
  end
  object BrushStyleCombo: TComboBox
    Left = 9
    Top = 206
    Width = 165
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 1
    TabStop = False
    Text = 'Solid'
    OnChange = BrushStyleComboChange
    Items.Strings = (
      'Solid'
      'Clear'
      'Horizontal'
      'Vertical'
      'Fwd diagonal'
      'Bwd diagonal'
      'Cross'
      'Diag cross')
  end
  object EditCoordinateSystem: TEdit
    Left = 10
    Top = 296
    Width = 166
    Height = 23
    TabStop = False
    ReadOnly = True
    TabOrder = 2
  end
  object OpacityTrackbar: TTrackBar
    Left = 8
    Top = 50
    Width = 166
    Height = 26
    Max = 255
    TabOrder = 3
    TickStyle = tsNone
    OnChange = OpacityTrackBarChange
  end
  object PenColorPanel: TPanel
    Left = 9
    Top = 98
    Width = 99
    Height = 26
    BevelOuter = bvLowered
    Color = clBlue
    ParentBackground = False
    TabOrder = 4
    StyleElements = [seFont, seBorder]
    OnClick = PenColorPanelClick
  end
  object PenStyleCombo: TComboBox
    Left = 9
    Top = 128
    Width = 165
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 5
    TabStop = False
    Text = 'Solid'
    OnChange = PenStyleComboChange
    Items.Strings = (
      'Solid'
      'Dash'
      'Dot'
      'Dash dot'
      'Dash dot dot')
  end
  object PenWidthSpinEdit: TSpinEdit
    Left = 114
    Top = 100
    Width = 60
    Height = 24
    MaxValue = 20
    MinValue = 1
    TabOrder = 6
    Value = 1
    OnChange = PenWidthSpinEditChange
  end
  object VisibleCheckBox: TCheckBox
    Left = 8
    Top = 11
    Width = 77
    Height = 17
    Caption = 'Visible'
    TabOrder = 7
    OnClick = VisibleCheckBoxClick
  end
  object PointComboBox: TComboBox
    Left = 10
    Top = 251
    Width = 98
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 8
    TabStop = False
    Text = 'Circle'
    OnChange = PointComboBoxChange
    Items.Strings = (
      'Circle'
      'Square'
      'Triangle Up'
      'Triangle Down')
  end
  object PointSizeSpinEdit: TSpinEdit
    Left = 114
    Top = 251
    Width = 60
    Height = 24
    MaxValue = 50
    MinValue = 1
    TabOrder = 9
    Value = 6
    OnChange = PointSizeSpinEditChange
  end
end
