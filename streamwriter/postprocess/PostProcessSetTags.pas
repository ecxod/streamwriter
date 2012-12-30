{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2013 Alexander Nottelmann

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
    ------------------------------------------------------------------------
}

unit PostProcessSetTags;

interface

uses
  Windows, SysUtils, Classes, PostProcess, LanguageObjects, AudioGenie,
  AddonAudioGenie, Functions, Logging, ConfigureSetTags, AudioFunctions,
  ExtendedStream, Generics.Collections, FileTagger;

type
  TPostProcessSetTagsThread = class(TPostProcessThreadBase)
  protected
    procedure Execute; override;
  public
    constructor Create(Data: PPostProcessInformation; PostProcessor: TPostProcessBase);
  end;

  TPostProcessSetTags = class(TInternalPostProcess)
  private
    FArtist: string;
    FTitle: string;
    FAlbum: string;
    FComment: string;
  protected
    function FGetHash: Cardinal; override;
  public
    constructor Create;

    function CanProcess(Data: PPostProcessInformation; ProcessingList: TList<TPostprocessBase>): Boolean; override;
    function ProcessFile(Data: PPostProcessInformation): TPostProcessThreadBase; override;
    function Copy: TPostProcessBase; override;
    procedure Assign(Source: TPostProcessBase); override;
    procedure Load(Stream: TExtendedStream; Version: Integer); override;
    procedure Save(Stream: TExtendedStream); override;
    procedure Initialize; override;
    function Configure(AOwner: TComponent; Handle: Cardinal; ShowMessages: Boolean): Boolean; override;
    procedure Save; override;
  end;

implementation

uses
  AppData;

{ TPostProcessSetTagsThread }

constructor TPostProcessSetTagsThread.Create(Data: PPostProcessInformation;
  PostProcessor: TPostProcessBase);
begin
  inherited Create(Data, PostProcessor);
end;

procedure TPostProcessSetTagsThread.Execute;
var
  Artist, Title, Album, Comment: string;
  Arr: TPatternReplaceArray;
  FileTagger: TFileTagger;
begin
  inherited;

  FResult := arFail;

  AppGlobals.Storage.Read('Artist_' + PostProcessor.ClassName, Artist, '%a', 'Plugins');
  AppGlobals.Storage.Read('Title_' + PostProcessor.ClassName, Title, '%t', 'Plugins');
  AppGlobals.Storage.Read('Album_' + PostProcessor.ClassName, Album, '%l', 'Plugins');
  AppGlobals.Storage.Read('Comment_' + PostProcessor.ClassName, Comment, '%s / %u / Recorded using streamWriter', 'Plugins');

  SetLength(Arr, 7);
  Arr[0].C := 'a';
  Arr[0].Replace := FData.Artist;
  Arr[1].C := 't';
  Arr[1].Replace := FData.Title;
  Arr[2].C := 'l';
  Arr[2].Replace := FData.Album;
  Arr[3].C := 's';
  Arr[3].Replace := Trim(FData.Station);
  Arr[4].C := 'u';
  Arr[4].Replace := Trim(FData.StreamTitle);
  Arr[5].C := 'd';
  Arr[5].Replace := FormatDateTime('dd.mm.yy', Now);
  Arr[6].C := 'i';
  Arr[6].Replace := FormatDateTime('hh.nn.ss', Now);

  FileTagger := TFileTagger.Create;
  try
    try
      if FileTagger.Read(FData.Filename) then
      begin
        Artist := PatternReplace(Artist, Arr);
        Title := PatternReplace(Title, Arr);
        Album := PatternReplace(Album, Arr);
        Comment := PatternReplace(Comment, Arr);

        FileTagger.Tag.Artist := Artist;
        FileTagger.Tag.Title := Title;
        FileTagger.Tag.Album := Album;
        FileTagger.Tag.TrackNumber := IntToStr(FData.TrackNumber);
        FileTagger.Tag.Comment := Comment;

        if FileTagger.Write(FData.Filename) then
        begin
          FData.Filesize := GetFileSize(FData.Filename);
          FResult := arWin;
        end;
      end;
    except
    end;
  finally
    FileTagger.Free;
  end;
end;

{ TPostProcessSetTags }

procedure TPostProcessSetTags.Assign(Source: TPostProcessBase);
begin
  inherited;

  FArtist := TPostProcessSetTags(Source).FArtist;
  FTitle := TPostProcessSetTags(Source).FTitle;
  FAlbum := TPostProcessSetTags(Source).FAlbum;
  FComment := TPostProcessSetTags(Source).FComment;
end;

function TPostProcessSetTags.CanProcess(Data: PPostProcessInformation; ProcessingList: TList<TPostProcessBase>): Boolean;
var
  i: Integer;
  M4AActive: Boolean;
begin
  M4AActive := False;
  if ProcessingList <> nil then
    for i := 0 to ProcessingList.Count - 1 do
      if (ProcessingList[i].PostProcessType = ptMP4Box) and (ProcessingList[i].Active) then
      begin
        M4AActive := True;
        Break;
      end;

  Result := ((FiletypeToFormat(Data.Filename) in [atMPEG, atOGG, atM4A]) or (M4AActive)) and FGetDependenciesMet;
end;

function TPostProcessSetTags.Configure(AOwner: TComponent; Handle: Cardinal;
  ShowMessages: Boolean): Boolean;
var
  F: TfrmConfigureSetTags;
begin
  Result := True;

  F := TfrmConfigureSetTags.Create(AOwner, Self, FArtist, FTitle, FAlbum, FComment);
  try
    F.ShowModal;

    if F.SaveData then
    begin
      FArtist := F.Artist;
      FTitle := F.Title;
      FAlbum := F.Album;
      FComment := F.Comment;

      Save;
    end;
  finally
    F.Free;
  end;
end;

function TPostProcessSetTags.Copy: TPostProcessBase;
begin
  Result := TPostProcessSetTags.Create;

  Result.Active := FActive;
  Result.Order := FOrder;
  Result.OnlyIfCut := FOnlyIfCut;

  Result.Assign(Self);
end;

constructor TPostProcessSetTags.Create;
begin
  inherited;

  FNeededAddons.Add(TAddonAudioGenie);

  FCanConfigure := True;
  FGroupID := 1;

  FName := _('Write tags to recorded songs');
  FHelp := _('This postprocessor writes tags to recorded songs.');

  FPostProcessType := ptSetTags;

  try
    AppGlobals.Storage.Read('Active_' + ClassName, FActive, False, 'Plugins');
    AppGlobals.Storage.Read('Order_' + ClassName, FOrder, 1010, 'Plugins');
    AppGlobals.Storage.Read('OnlyIfCut_' + ClassName, FOnlyIfCut, False, 'Plugins');

    AppGlobals.Storage.Read('Artist_' + ClassName, FArtist, '%a', 'Plugins');
    AppGlobals.Storage.Read('Album_' + ClassName, FAlbum, '%l', 'Plugins');
    AppGlobals.Storage.Read('Title_' + ClassName, FTitle, '%t', 'Plugins');
    AppGlobals.Storage.Read('Comment_' + ClassName, FComment, '%s / %u / Recorded using streamWriter', 'Plugins');

    if not FGetDependenciesMet then
      FActive := False;
  except end;
end;

function TPostProcessSetTags.FGetHash: Cardinal;
begin
  Result := inherited + HashString(FArtist + FAlbum + FTitle + FComment);
end;

procedure TPostProcessSetTags.Initialize;
begin
  inherited;

  FName := _('Write tags to recorded songs');
  FHelp := _('This postprocessor writes tags to recorded songs.');
end;

procedure TPostProcessSetTags.Load(Stream: TExtendedStream;
  Version: Integer);
begin
  inherited;

  Stream.Read(FArtist);
  Stream.Read(FAlbum);
  Stream.Read(FTitle);
  Stream.Read(FComment);
end;

function TPostProcessSetTags.ProcessFile(Data: PPostProcessInformation): TPostProcessThreadBase;
begin
  Result := TPostProcessSetTagsThread.Create(Data, Self);
end;

procedure TPostProcessSetTags.Save(Stream: TExtendedStream);
begin
  inherited;

  Stream.Write(FArtist);
  Stream.Write(FAlbum);
  Stream.Write(FTitle);
  Stream.Write(FComment);
end;

procedure TPostProcessSetTags.Save;
begin
  inherited;

  AppGlobals.Storage.Write('Artist_' + ClassName, FArtist, 'Plugins');
  AppGlobals.Storage.Write('Title_' + ClassName, FTitle, 'Plugins');
  AppGlobals.Storage.Write('Album_' + ClassName, FAlbum, 'Plugins');
  AppGlobals.Storage.Write('Comment_' + ClassName, FComment, 'Plugins');
end;

end.
