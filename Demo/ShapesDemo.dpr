program ShapesDemo;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
////////////////////////////////////////////////////////////////////////////////

uses
  Vcl.Forms,
  Main in 'Main.pas' {MainForm},
  Vcl.Themes,
  Vcl.Styles,
  RndrCtrl in 'RndrCtrl.pas' {LayerRenderingControl: TFrame},
  RndrCtrl.Default in 'RndrCtrl.Default.pas' {TDefaultLayerRenderingControl: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Slate Classico');
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
