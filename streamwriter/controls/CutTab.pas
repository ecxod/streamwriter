{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2018 Alexander Nottelmann

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

{ This unit contains the TabControl to display cutting of recorded files }
unit CutTab;

interface

uses
  Windows, SysUtils, Classes, Controls, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  MControls, LanguageObjects, Tabs, CutView, Functions, AppData, SharedControls,
  DynBass, Logging, CutTabSearchSilence, MessageBus, AppMessages, PlayerManager,
  Forms, DataManager, AudioFunctions, SharedData, Messages;

type
  TCutToolBar = class(TToolBar)
  private
    FSave: TToolButton;
    FSep: TToolButton;
    FZoomIn: TToolButton;
    FZoomOut: TToolButton;
    FPosEdit: TToolButton;
    FPosPlay: TToolButton;
    FAutoCut: TToolButton;
    FCut: TToolButton;
    FUndo: TToolButton;
    FPosEffectsMarker: TToolButton;
    FApplyFadein: TToolButton;
    FApplyFadeout: TToolButton;
    FApplyEffects: TToolButton;
    FPlay: TToolButton;
    FStop: TToolButton;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Setup;
  end;

  TFileSavedEvent = procedure(Sender: TObject; AudioInfo: TAudioInfo) of object;

  TCutTab = class(TMainTabSheet)
  private
    FToolbarPanel: TPanel;
    FToolBar: TCutToolBar;
    FVolume: TVolumePanel;
    FCutView: TCutView;
    FFilename: string;
    FTrack: TTrackInfo;

    FOnSaved: TFileSavedEvent;
    FOnPlayStarted: TNotifyEvent;

    procedure UpdateButtons;

    procedure SaveClick(Sender: TObject);
    procedure PosClick(Sender: TObject);
    procedure AutoCutClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure ApplyFadeinClick(Sender: TObject);
    procedure ApplyFadeoutClick(Sender: TObject);
    procedure ApplyEffectsClick(Sender: TObject);
    procedure ZoomInClick(Sender: TObject);
    procedure ZoomOutClick(Sender: TObject);

    procedure CutViewStateChanged(Sender: TObject);
    procedure VolumeTrackbarChange(Sender: TObject);
    function VolumeGetVolumeBeforeMute(Sender: TObject): Integer;

    procedure MessageReceived(Msg: TMessageBase);
  public
    constructor Create(AOwner: TComponent; Track: TTrackInfo; Filename: string = ''); reintroduce;
    destructor Destroy; override;
    procedure AfterCreate; override;

    procedure PausePlay;

    function CanClose: Boolean; override;

    function ProcessShortCut(Msg: TWMKey): Boolean; override;

    property Filename: string read FFilename;

    property CutView: TCutView read FCutView;
    property OnSaved: TFileSavedEvent read FOnSaved write FOnSaved;
    property OnPlayStarted: TNotifyEvent read FOnPlayStarted write FOnPlayStarted;
  end;

implementation

{ TCutTab }

function TCutTab.CanClose: Boolean;
begin
  Result := inherited;

  if FCutView.WaveData <> nil then
    if FCutView.LastCheckSum <> FCutView.WaveData.CheckSum then
    begin
      if MsgBox(GetParentForm(Self).Handle, Format(_('The file "%s" has not been saved. Do you really want to close the editor?'), [ExtractFileName(FFilename)]),
        _('Question'), MB_ICONQUESTION or MB_YESNO or MB_DEFBUTTON2) = IDYES then
        Result := True
      else
        Result := False;
    end;
end;

constructor TCutTab.Create(AOwner: TComponent; Track: TTrackInfo; Filename: string = '');
begin
  inherited Create(AOwner);

  FTrack := Track;
  if Track <> nil then
    FFilename := Track.Filename
  else
    FFilename := Filename;

  FToolbarPanel := TPanel.Create(Self);
  FToolbarPanel.Parent := Self;

  FToolBar := TCutToolBar.Create(Self);
  FToolBar.Parent := FToolbarPanel;

  FVolume := TVolumePanel.Create(Self);
  FVolume.Parent := FToolbarPanel;

  FCutView := TCutView.Create(Self);
  FCutView.Parent := Self;

  MsgBus.AddSubscriber(MessageReceived);

  ImageIndex := 17;
  ShowCloseButton := True;
end;

procedure TCutTab.UpdateButtons;
begin
  FToolBar.FSave.Enabled := FCutView.CanSave;
  FToolBar.FPosEdit.Enabled := FCutView.CanSetLine;
  FToolBar.FPosPlay.Enabled := FCutView.CanSetLine;
  FToolBar.FAutoCut.Enabled := FCutView.CanAutoCut;
  FToolBar.FPosPlay.Enabled := FCutView.CanSetLine;
  FToolBar.FCut.Enabled := FCutView.CanCut;
  FToolBar.FZoomIn.Enabled := FCutView.CanZoomIn;
  FToolBar.FZoomOut.Enabled := FCutView.CanZoomOut;
  FToolBar.FPosEffectsMarker.Enabled := FCutView.CanEffectsMarker;
  FToolBar.FUndo.Enabled := FCutView.CanUndo;
  FToolBar.FApplyFadein.Enabled := FCutView.CanApplyFadeIn;
  FToolBar.FApplyFadeout.Enabled := FCutView.CanApplyFadeOut;
  FToolBar.FApplyEffects.Enabled := FCutView.CanApplyEffects;
  FToolBar.FPlay.Enabled := FCutView.CanPlay and Bass.DeviceAvailable;
  FToolBar.FStop.Enabled := FCutView.CanStop and Bass.DeviceAvailable;

  // Das muss so, sonst klappt das .Down := True nicht, wenn sie
  // vorher Disabled waren, vor dem Enable da oben...
  FToolBar.FPosEdit.Down := False;
  FToolBar.FPosPlay.Down := False;
  FToolBar.FPosEffectsMarker.Down := False;

  case FCutView.LineMode of
    lmEdit:
      FToolBar.FPosEdit.Down := True;
    lmPlay:
      FToolBar.FPosPlay.Down := True;
    lmEffectsMarker:
      FToolBar.FPosEffectsMarker.Down := True;
  end;
end;

function TCutTab.VolumeGetVolumeBeforeMute(Sender: TObject): Integer;
begin
  Result := Players.VolumeBeforeMute;
end;

procedure TCutTab.VolumeTrackbarChange(Sender: TObject);
begin
  Players.Volume := FVolume.Volume;
  if FVolume.VolumeBeforeDrag > -1 then
    Players.VolumeBeforeMute := FVolume.VolumeBeforeDrag;
end;

procedure TCutTab.ZoomInClick(Sender: TObject);
begin
  FCutView.ZoomIn;
end;

procedure TCutTab.ZoomOutClick(Sender: TObject);
begin
  FCutView.ZoomOut;
end;

procedure TCutTab.PosClick(Sender: TObject);
begin
  if TToolButton(Sender).Down then
    Exit;

  FToolBar.FPosEdit.Down := False;
  FToolBar.FPosPlay.Down := False;
  FToolBar.FPosEffectsMarker.Down := False;

  if Sender = FToolBar.FPosEdit then
  begin
    FCutView.LineMode := lmEdit;
    FToolBar.FPosEdit.Down := True;
  end;
  if Sender = FToolBar.FPosPlay then
  begin
    FCutView.LineMode := lmPlay;
    FToolBar.FPosPlay.Down := True;
  end;
  if Sender = FToolBar.FPosEffectsMarker then
  begin
    FCutView.LineMode := lmEffectsMarker;
    FToolBar.FPosEffectsMarker.Down := True;
  end;
end;

function TCutTab.ProcessShortCut(Msg: TWMKey): Boolean;
var
  Button: TToolButton;
begin
  Result := False;
  Button := nil;

  if (GetKeyState(VK_CONTROL) < 0) and (GetKeyState(VK_MENU) = 0) then
  begin
    if Msg.CharCode = Ord('S') then
      Button := FToolBar.FSave;
    if Msg.CharCode = Ord('Z') then
      Button := FToolBar.FUndo;
  end else
  begin
    if Msg.CharCode = VK_SPACE then
    begin
      if FCutView.Player.Playing then
        Button := FToolBar.FStop
      else
        Button := FToolBar.FPlay;
    end;

    if Msg.CharCode = VK_HOME then
    begin
      FCutView.SetPosition(True);
      Result := True;
    end;

    if Msg.CharCode = VK_END then
    begin
      FCutView.SetPosition(False);
      Result := True;
    end;

    if Msg.CharCode = Ord('S') then
      Button := FToolBar.FPosEffectsMarker;

    if (Msg.CharCode = VK_ADD) or (Msg.CharCode = VK_OEM_PLUS) then
      Button := FToolBar.FZoomIn;

    if (Msg.CharCode = VK_SUBTRACT) or (Msg.CharCode = VK_OEM_MINUS) then
      Button := FToolBar.FZoomOut;

    if Msg.CharCode = Ord('P') then
      Button := FToolBar.FPosPlay;

    if Msg.CharCode = Ord('C') then
      Button := FToolBar.FPosEdit;

    if Msg.CharCode = Ord('F') then
      FCutView.ApplyFade;
  end;

  if Button <> nil then
  begin
    if Button.Enabled then
      Button.Click;
    Result := True;
  end;
end;

procedure TCutTab.ApplyFadeinClick(Sender: TObject);
begin
  FCutView.ApplyFade;
end;

procedure TCutTab.ApplyFadeoutClick(Sender: TObject);
begin
  FCutView.ApplyFade;
end;

procedure TCutTab.ApplyEffectsClick(Sender: TObject);
begin
  FCutView.ApplyEffects;
end;

procedure TCutTab.AutoCutClick(Sender: TObject);
var
  F: TfrmCutTabSearchSilence;
begin
  F := TfrmCutTabSearchSilence.Create(Self, False);
  try
    F.ShowModal;

    if F.Okay then
    begin
      FCutView.AutoCut(F.SilenceLevel, F.SilenceLength);
    end;
  finally
    F.Free;
  end;
end;

procedure TCutTab.CutClick(Sender: TObject);
begin
  FCutView.Cut;
end;

procedure TCutTab.UndoClick(Sender: TObject);
begin
  FCutView.Undo;
end;

procedure TCutTab.PausePlay;
begin
  FCutView.Stop;
end;

procedure TCutTab.PlayClick(Sender: TObject);
begin
  FCutView.Play;

  if Assigned(FOnPlayStarted) then
    FOnPlayStarted(Self);
end;

procedure TCutTab.StopClick(Sender: TObject);
begin
  FCutView.Stop;
end;

procedure TCutTab.CutViewStateChanged(Sender: TObject);
begin
  UpdateButtons;
end;

destructor TCutTab.Destroy;
begin
  MsgBus.RemoveSubscriber(MessageReceived);

  inherited;
end;

procedure TCutTab.MessageReceived(Msg: TMessageBase);
var
  VolMsg: TVolumeChangedMsg;
begin
  if Msg is TVolumeChangedMsg then
  begin
    VolMsg := TVolumeChangedMsg(Msg);

    if VolMsg.Volume <> FVolume.Volume then
      FVolume.Volume := TVolumeChangedMsg(Msg).Volume;
  end;
end;

procedure TCutTab.SaveClick(Sender: TObject);
begin
  FCutView.Save;
end;

procedure TCutTab.AfterCreate;
begin
  inherited;

  if FTrack <> nil then
  begin
    Caption := ExtractFileName(StringReplace(FTrack.Filename, '&', '&&', [rfReplaceAll]));
    FCutView.LoadFile(FTrack);
  end else
  begin
    Caption := ExtractFileName(StringReplace(Filename, '&', '&&', [rfReplaceAll]));
    FCutView.LoadFile(Filename, False, True);
  end;

  MaxWidth := 120;

  FToolbarPanel.Align := alTop;
  FToolbarPanel.BevelOuter := bvNone;
  FToolbarPanel.ClientHeight := 25;
  FToolbarPanel.Padding.Top := 1;

  FToolBar.Images := modSharedData.imgImages;
  FToolBar.Align := alLeft;
  FToolBar.Width := Self.ClientWidth - 130;
  FToolBar.Height := 24;
  FToolBar.Indent := 2;
  FToolBar.Setup;

  FToolbar.FSave.OnClick := SaveClick;
  FToolBar.FPosEdit.OnClick := PosClick;
  FToolBar.FPosPlay.OnClick := PosClick;
  FToolBar.FZoomIn.OnClick := ZoomInClick;
  FToolBar.FZoomOut.OnClick := ZoomOutClick;
  FToolBar.FPosEffectsMarker.OnClick := PosClick;
  FToolBar.FAutoCut.OnClick := AutoCutClick;

  {$IFDEF DEBUG}
  //FToolBar.FAutoCutAutoDetect.OnClick := AutoCutAutoDetectClick;
  {$ENDIF}

  FToolBar.FCut.OnClick := CutClick;
  FToolBar.FUndo.OnClick := UndoClick;
  FToolBar.FApplyFadein.OnClick := ApplyFadeinClick;
  FToolBar.FApplyFadeout.OnClick := ApplyFadeoutClick;
  FToolBar.FApplyEffects.OnClick := ApplyEffectsClick;
  FToolBar.FPlay.OnClick := PlayClick;
  FToolBar.FStop.OnClick := StopClick;

  FVolume.Align := alRight;
  FVolume.Setup;
  FVolume.Enabled := Bass.DeviceAvailable;
  FVolume.Width := 140;
  FVolume.Padding.Bottom := 2;
  FVolume.Volume := Players.Volume;
  FVolume.OnVolumeChange := VolumeTrackbarChange;
  FVolume.OnGetVolumeBeforeMute := VolumeGetVolumeBeforeMute;

  FCutView.Padding.Top := 2;
  FCutView.Align := alClient;
  FCutView.OnStateChanged := CutViewStateChanged;

  UpdateButtons;
  Language.Translate(Self);
end;

{ TCutToolbar }

constructor TCutToolBar.Create(AOwner: TComponent);
begin
  inherited;

  ShowHint := True;
  Transparent := True;
end;

procedure TCutToolBar.Setup;
begin
  FStop := TToolButton.Create(Self);
  FStop.Parent := Self;
  FStop.Hint := 'Stop (Space bar)';
  FStop.ImageIndex := 1;

  FPlay := TToolButton.Create(Self);
  FPlay.Parent := Self;
  FPlay.Hint := 'Play (Space bar)';
  FPlay.ImageIndex := 33;

  FPosPlay := TToolButton.Create(Self);
  FPosPlay.Parent := Self;
  FPosPlay.Hint := 'Set playposition (P)';
  FPosPlay.ImageIndex := 27;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FAutoCut := TToolButton.Create(Self);
  FAutoCut.Parent := Self;
  FAutoCut.Hint := 'Show silence...';
  FAutoCut.ImageIndex := 19;

  {$IFDEF DEBUG}
  //FAutoCutAutoDetect := TToolButton.Create(Self);
  //FAutoCutAutoDetect.Parent := Self;
  //FAutoCutAutoDetect.Hint := 'Show silence...';
  //FAutoCutAutoDetect.ImageIndex := 19;
  {$ENDIF}

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FUndo := TToolButton.Create(Self);
  FUndo.Parent := Self;
  FUndo.Hint := 'Undo (Ctrl+Z)';
  FUndo.ImageIndex := 18;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FApplyEffects := TToolButton.Create(Self);
  FApplyEffects.Parent := Self;
  FApplyEffects.Hint := 'Apply effects...';
  FApplyEffects.ImageIndex := 56;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FCut := TToolButton.Create(Self);
  FCut.Parent := Self;
  FCut.Hint := 'Cut song';
  FCut.ImageIndex := 17;

  FPosEdit := TToolButton.Create(Self);
  FPosEdit.Parent := Self;
  FPosEdit.Hint := 'Set cutpositions (left mousebutton sets start, right button sets end) (C)';
  FPosEdit.ImageIndex := 37;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FApplyFadeout := TToolButton.Create(Self);
  FApplyFadeout.Parent := Self;
  FApplyFadeout.Hint := 'Apply fadeout (F)';
  FApplyFadeout.ImageIndex := 55;

  FApplyFadein := TToolButton.Create(Self);
  FApplyFadein.Parent := Self;
  FApplyFadein.Hint := 'Apply fadein (F)';
  FApplyFadein.ImageIndex := 54;

  FZoomOut := TToolButton.Create(Self);
  FZoomOut.Parent := Self;
  FZoomOut.Hint := 'Zoom out (-)';
  FZoomOut.ImageIndex := 66;

  FZoomIn := TToolButton.Create(Self);
  FZoomIn.Parent := Self;
  FZoomIn.Hint := 'Zoom in (+)';
  FZoomIn.ImageIndex := 48;

  FPosEffectsMarker := TToolButton.Create(Self);
  FPosEffectsMarker.Parent := Self;
  FPosEffectsMarker.Hint := 'Select area (S)';
  FPosEffectsMarker.ImageIndex := 53;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FSave := TToolButton.Create(Self);
  FSave.Parent := Self;
  FSave.Hint := 'Save (Ctrl+S)';
  FSave.ImageIndex := 14;
end;

end.

