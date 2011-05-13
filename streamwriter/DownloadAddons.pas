unit DownloadAddons;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, ComCtrls, Plugins, DownloadClient,
  Functions, LanguageObjects, AppData, Logging;

type
  TfrmDownloadAddons = class(TForm)
    Label1: TLabel;
    ProgressBar1: TProgressBar;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
  private
    FDownloader: TDownloadClient;
    FDownloaded: Boolean;
    FError: Boolean;
    FPlugin: TInternalPlugin;

    procedure DownloaderDownloadProgress(Sender: TObject);
    procedure DownloaderDownloaded(Sender: TObject);
    procedure DownloaderError(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; Plugin: TInternalPlugin);
    property Downloaded: Boolean read FDownloaded;
    property Error: Boolean read FError;
  end;

implementation

{$R *.dfm}

constructor TfrmDownloadAddons.Create(AOwner: TComponent; Plugin: TInternalPlugin);
var
  URL: string;
begin
  inherited Create(AOwner);

  FPlugin := Plugin;

  Language.Translate(Self);
end;

procedure TfrmDownloadAddons.DownloaderDownloaded(Sender: TObject);
begin
  FDownloader.Thread.RecvDataStream.Seek(0, soFromBeginning);

  try
    FDownloader.Thread.RecvDataStream.SaveToFile(AppGlobals.Storage.DataDir + FPlugin.DownloadPackage);
    FDownloaded := True;
  except
    FError := True;
  end;

  Close;
end;

procedure TfrmDownloadAddons.DownloaderDownloadProgress(Sender: TObject);
begin
  if FDownloader.Percent < 100 then
    ProgressBar1.Position := FDownloader.Percent + 1;
  ProgressBar1.Position := FDownloader.Percent;
end;

procedure TfrmDownloadAddons.DownloaderError(Sender: TObject);
begin
  FError := True;
  Close;
end;

procedure TfrmDownloadAddons.FormActivate(Sender: TObject);
var
  URL: string;
begin
  if FDownloader <> nil then
    Exit;

  if AppGlobals.Language <> '' then
    URL := AppGlobals.ProjectUpdateLink + Trim(AppGlobals.Language) + '/downloads/getaddon/' + LowerCase(AppGlobals.AppName) + '/' + AppGlobals.AppVersion.AsString + '/' + LowerCase(FPlugin.DownloadName) + '/'
  else
    URL := AppGlobals.ProjectUpdateLink + 'en/downloads/getaddon/' + LowerCase(AppGlobals.AppName) + '/' + AppGlobals.AppVersion.AsString + '/' + LowerCase(FPlugin.DownloadName) + '/';

  FDownloader := TDownloadClient.Create(URL);
  FDownloader.OnDownloadProgress := DownloaderDownloadProgress;
  FDownloader.OnDownloaded := DownloaderDownloaded;
  FDownloader.OnError := DownloaderError;
  FDownloader.Start;
end;

procedure TfrmDownloadAddons.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  FDownloader.Kill;
  FDownloader.Free;
end;

end.
