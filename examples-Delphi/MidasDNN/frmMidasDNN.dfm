object Form7: TForm7
  Left = 0
  Top = 0
  Caption = 'Depth estimation with Midas DNN'
  ClientHeight = 183
  ClientWidth = 413
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 13
  object lbl1: TLabel
    Left = 16
    Top = 16
    Width = 65
    Height = 13
    AutoSize = False
    Caption = 'Input image'
  end
  object lblTime: TLabel
    Left = 24
    Top = 144
    Width = 321
    Height = 13
    AutoSize = False
  end
  object btn1: TButton
    Left = 176
    Top = 80
    Width = 75
    Height = 25
    Caption = 'Start '
    TabOrder = 0
    OnClick = btn1Click
  end
  object txImg1: TEdit
    Left = 16
    Top = 35
    Width = 358
    Height = 21
    TabOrder = 1
    Text = '..\..\testimg.jpg'
  end
  object btnLoad1: TButton
    Left = 380
    Top = 35
    Width = 25
    Height = 25
    Caption = '...'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    TabOrder = 2
    OnClick = btnLoad1Click
  end
  object dlgOpen1: TOpenDialog
    Left = 328
    Top = 80
  end
end
