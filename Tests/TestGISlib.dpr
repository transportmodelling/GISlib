program TestGISlib;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/GISlib
//
// Test suite generated with assistance from Claude Sonnet 4.6
//
////////////////////////////////////////////////////////////////////////////////

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.JUnit,
  // FireDAC - console-safe registrations (no VCL dependency)
  FireDAC.Stan.Def,
  FireDAC.DApt,
  FireDAC.ConsoleUI.Wait,   // console wait-cursor (replaces VCLUI.Wait)
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  Test.Geometry   in 'Test.Geometry.pas',
  Test.Mercator   in 'Test.Mercator.pas',
  Test.CoordConv  in 'Test.CoordConv.pas',
  Test.PixelConv  in 'Test.PixelConv.pas',
  Test.Shapes     in 'Test.Shapes.pas',
  Test.Geopackage in 'Test.Geopackage.pas',
  Test.Writers    in 'Test.Writers.pas',
  Test.Polygon    in 'Test.Polygon.pas';

begin
  var FireDACManager := TFDManager.Create(nil);
  try
    try
      // Initialization
      TDUnitX.CheckCommandLine;
      TDUnitX.Options.XMLOutputFile := '.\TestUtils.xml';
      ReportMemoryLeaksOnShutdown := True;
      FireDACManager.SilentMode := True;
      // Create the test Runner
      var Runner := TDUnitX.CreateRunner;
      Runner.UseRTTI := True;
      Runner.FailsOnNoAsserts := False;
      // Create loggers
      var ConsoleLogger := TDUnitXConsoleLogger.Create(false);
      var JUnitLogger := TDUnitXXMLJUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      Runner.AddLogger(ConsoleLogger);
      Runner.AddLogger(JUnitLogger);
      //Run tests
      var Results := Runner.Execute;
      if not Results.AllPassed then System.ExitCode := EXIT_ERRORS;
    except
      on E: Exception do
      begin
        Writeln(E.ClassName, ': ', E.Message);
        System.ExitCode := 2;
      end;
    end;
  finally
    FireDACManager.Free;
  end;
end.
