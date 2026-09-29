inherited DefaultLayerRenderingControl: TDefaultLayerRenderingControl
  Height = 410
  ExplicitHeight = 410
  object GeneralSection: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 80
    BevelOuter = bvNone
    TabOrder = 0
    object OpacityLabel: TLabel
      Left = 8
      Top = 34
      Width = 41
      Height = 15
      Caption = 'Opacity'
    end
    object VisibleCheckBox: TCheckBox
      Left = 8
      Top = 11
      Width = 77
      Height = 17
      Caption = 'Visible'
      TabOrder = 0
      OnClick = VisibleCheckBoxClick
    end
    object OpacityTrackbar: TTrackBar
      Left = 8
      Top = 50
      Width = 166
      Height = 26
      Max = 255
      TabOrder = 1
      TickStyle = tsNone
      OnChange = OpacityTrackBarChange
    end
  end
  object PenSection: TPanel
    Left = 0
    Top = 80
    Width = 185
    Height = 78
    BevelOuter = bvNone
    TabOrder = 1
    object PenLabel: TLabel
      Left = 8
      Top = 2
      Width = 20
      Height = 15
      Caption = 'Pen'
    end
    object PenColorPanel: TPanel
      Left = 9
      Top = 18
      Width = 99
      Height = 26
      BevelOuter = bvLowered
      Color = clBlue
      ParentBackground = False
      TabOrder = 0
      StyleElements = [seFont, seBorder]
      OnClick = PenColorPanelClick
    end
    object PenWidthSpinEdit: TSpinEdit
      Left = 114
      Top = 20
      Width = 60
      Height = 24
      MaxValue = 20
      MinValue = 1
      TabOrder = 1
      Value = 1
      OnChange = PenWidthSpinEditChange
    end
    object PenStyleCombo: TComboBox
      Left = 9
      Top = 48
      Width = 165
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 2
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
  end
  object BrushSection: TPanel
    Left = 0
    Top = 158
    Width = 185
    Height = 75
    BevelOuter = bvNone
    TabOrder = 2
    object BrushLabel: TLabel
      Left = 8
      Top = 2
      Width = 30
      Height = 15
      Caption = 'Brush'
    end
    object BrushColorPanel: TPanel
      Left = 9
      Top = 18
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
      Top = 48
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
  end
  object PointsSection: TPanel
    Left = 0
    Top = 233
    Width = 185
    Height = 47
    BevelOuter = bvNone
    TabOrder = 3
    object PointLabel: TLabel
      Left = 8
      Top = 2
      Width = 33
      Height = 15
      Caption = 'Points'
    end
    object PointComboBox: TComboBox
      Left = 10
      Top = 18
      Width = 98
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      TabStop = False
      Text = 'Circle'
      OnChange = PointComboBoxChange
      Items.Strings = (
        'Circle'
        'Square'
        'Triangle up'
        'Triangle down'
        'Station 18 px'
        'Station 24 px'
        'Station 36 px'
        'Station 48 px'
        'Airport 18 px'
        'Airport 24 px'
        'Airport 36 px'
        'Airport 48 px')
    end
    object PointSizeSpinEdit: TSpinEdit
      Left = 114
      Top = 18
      Width = 60
      Height = 24
      MaxValue = 50
      MinValue = 1
      TabOrder = 1
      Value = 6
      OnChange = PointSizeSpinEditChange
    end
  end
  object LabelsSection: TPanel
    Left = 0
    Top = 280
    Width = 185
    Height = 78
    BevelOuter = bvNone
    TabOrder = 4
    object LabelsLabel: TLabel
      Left = 8
      Top = 2
      Width = 33
      Height = 15
      Caption = 'Labels'
    end
    object LabelSourceCombo: TComboBox
      Left = 9
      Top = 18
      Width = 165
      Height = 23
      Hint = 'Label polygons with their feature number or an attribute'
      Style = csDropDownList
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      TabStop = False
      OnChange = LabelSourceComboChange
    end
    object TextColorPanel: TPanel
      Left = 9
      Top = 46
      Width = 99
      Height = 26
      Hint = 'Text color'
      BevelOuter = bvLowered
      Color = clBlack
      ParentBackground = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      StyleElements = [seFont, seBorder]
      OnClick = TextColorPanelClick
    end
    object TextSizeSpinEdit: TSpinEdit
      Left = 114
      Top = 48
      Width = 60
      Height = 24
      Hint = 'Text size (points)'
      MaxValue = 72
      MinValue = 6
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      Value = 9
      OnChange = TextSizeSpinEditChange
    end
  end
  object CoordSystemSection: TPanel
    Left = 0
    Top = 358
    Width = 185
    Height = 52
    BevelOuter = bvNone
    TabOrder = 5
    object CoordinateSystemLabel: TLabel
      Left = 11
      Top = 4
      Width = 99
      Height = 15
      Caption = 'Coordinate system'
    end
    object EditCoordinateSystem: TEdit
      Left = 10
      Top = 18
      Width = 166
      Height = 23
      TabStop = False
      ReadOnly = True
      TabOrder = 0
    end
  end
end
