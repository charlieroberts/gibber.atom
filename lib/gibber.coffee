AudioContext = require('web-audio-api').AudioContext
_ = require 'underscore-plus'

Speaker = require('speaker')
Gibber = global.Gibber = require 'gibber.core.lib'
AudioConstructor = require 'gibber.audio.lib'

global.AudioContext = global.webkitAudioContext = AudioContext

{CompositeDisposable} = require 'atom'
{allowUnsafeEval, Function} = require 'loophole'
global.Function = Function
global.eval = allowUnsafeEval

Gibber.Audio = Audio = AudioConstructor( Gibber )
Gibber.Audio.export( global )

global.$ = Gibber.dollar

try
  Gibber.init()
catch e
  console.log( e )

Gibberish = Audio.Core
Gibberish.node.disconnect()

# HACK: Gibber.init partially fails, so we have to make up the slack below...
Gibberish.context = new AudioContext()

Gibberish.context.outStream = new Speaker({
  channels: 2,
  bitDepth: 16,
  sampleRate: Gibberish.context.sampleRate
})
Gibberish.node = Gibberish.context.createScriptProcessor(1024, 2, 2, Gibberish.context.sampleRate)

Gibberish.node.onaudioprocess = Gibberish.audioProcess
Gibberish.out = new Gibberish.Bus2()
Gibberish.out.codegen() # make sure bus is first upvalue so that clearing works correctly
Gibberish.dirty(Gibberish.out)
Gibberish.node.connect( Gibberish.context.destination )

$.extend( Gibber.Binops, Audio.Binops )

Audio.Master = Audio.Busses.Bus().connect( Audio.Core.out )

Audio.Master.type = 'Bus'
Audio.Master.name = 'Master'

$.extend( true, Audio.Master, Audio.ugenTemplate )
Audio.Master.fx.ugen = Audio.Master

Audio.ugenTemplate.connect =
  Audio.Core._oscillator.connect =
  Audio.Core._synth.connect =
  Audio.Core._effect.connect =
  Audio.Core._bus.connect =
  Audio.connect;

Audio.Core.defineUgenProperty = Audio.defineUgenProperty

$.extend( Gibber.Presets, Audio.Synths.Presets )
$.extend( Gibber.Presets, Audio.Percussion.Presets )
$.extend( Gibber.Presets, Audio.FX.Presets )

Audio.Clock.start( true )

# end HACK

module.exports = _Gibber =
  activate: (state) ->
    atom.commands.add 'atom-workspace', 'gibber:execute', => @execute()
    atom.commands.add 'atom-workspace', 'gibber:delayedExecute', => @delayedExecute()
    atom.commands.add 'atom-workspace', 'gibber:clear', => @clear()

  clear: ->
    Gibber.clear()

  execute: (state)->
    editor = atom.workspace.getActivePaneItem()
    selectionRange = editor.getLastSelection()

    if selectionRange.start == selectionRange.end
      selectionRange = editor.cursors[0].getCurrentLineBufferRange()

    @highlight editor, selectionRange

    allowUnsafeEval ->
      eval( editor.getTextInBufferRange( selectionRange ) )

  delayedExecute: ( state ) ->
    editor = atom.workspace.getActivePaneItem()
    selectionRange = editor.getLastSelection()

    if selectionRange.start == selectionRange.end
      selectionRange = editor.cursors[0].getCurrentLineBufferRange()

    @highlight editor, selectionRange

    Audio.Clock.codeToExecute.push({
      function: new Function( editor.getTextInBufferRange( selectionRange ) )
    })

  highlight: ( editor, range ) ->
    marker = editor.markBufferRange range,
      invalidate: 'never'
      persistent: true

    decoration = editor.decorateMarker marker,
      type: 'line'
      class: 'gibbering'

    setTimeout ->
      decoration.destroy()
    , 50
