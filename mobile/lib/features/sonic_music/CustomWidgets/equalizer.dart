/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:math';

import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

class Equalizer extends StatefulWidget {
  const Equalizer({super.key});

  @override
  _EqualizerState createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> {
  bool enabled =
      Hive.box('settings').get('setEqualizer', defaultValue: false) as bool;
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      content: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.equalizer),
              value: enabled,
              activeThumbColor: Theme.of(context).colorScheme.secondary,
              onChanged: (value) {
                enabled = value;
                Hive.box('settings').put('setEqualizer', value);
                audioHandler.customAction('setEqualizer', {'value': value});
                setState(() {});
              },
            ),
            if (enabled)
              SizedBox(
                height: MediaQuery.sizeOf(context).height / 2,
                child: EqualizerControls(
                  audioHandler: audioHandler,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EqualizerControls extends StatefulWidget {
  final AudioPlayerHandler audioHandler;
  const EqualizerControls({super.key, required this.audioHandler});
  @override
  _EqualizerControlsState createState() => _EqualizerControlsState();
}

class _EqualizerControlsState extends State<EqualizerControls> {
  late Future<Map> _eqFuture;
  String _selectedPreset = 'Custom';

  @override
  void initState() {
    super.initState();
    _eqFuture = _fetchEq();
  }

  Future<Map> _fetchEq() async {
    return await widget.audioHandler.customAction('getEqualizerParams') as Map;
  }

  final Map<String, List<double>> presets = {
    'Flat': [0.5, 0.5, 0.5, 0.5, 0.5],
    'Bass Boost': [0.8, 0.7, 0.5, 0.5, 0.5],
    'Electronic': [0.75, 0.65, 0.5, 0.6, 0.7],
    'Acoustic': [0.65, 0.55, 0.55, 0.65, 0.55],
    'Vocal Boost': [0.4, 0.5, 0.65, 0.75, 0.6],
  };

  void _applyPreset(String name, List<double> gains) {
    for (int i = 0; i < gains.length; i++) {
      Hive.box('settings').put('equalizerBand$i', gains[i]);
      widget.audioHandler.customAction('setBandGain', {'band': i, 'gain': gains[i]});
    }
    setState(() {
      _selectedPreset = name;
      _eqFuture = _fetchEq();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map>(
      future: _eqFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox();
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox();
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.keys.map((presetName) {
                  final isSelected = _selectedPreset == presetName;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(presetName),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _applyPreset(presetName, presets[presetName]!);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  for (final band in data['bands'] as List<Map>)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: VerticalSlider(
                              min: data['minDecibels'] as double,
                              max: data['maxDecibels'] as double,
                              value: band['gain'] as double,
                              bandIndex: band['index'] as int,
                              audioHandler: widget.audioHandler,
                            ),
                          ),
                          Text(
                            '${band['centerFrequency'].round()}\nHz',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class VerticalSlider extends StatefulWidget {
  final double? value;
  final double? min;
  final double? max;
  final int bandIndex;
  final AudioPlayerHandler audioHandler;

  const VerticalSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.bandIndex,
    required this.audioHandler,
  });

  @override
  _VerticalSliderState createState() => _VerticalSliderState();
}

class _VerticalSliderState extends State<VerticalSlider> {
  double? sliderValue;

  void setGain(int bandIndex, double gain) {
    Hive.box('settings').put('equalizerBand$bandIndex', gain);
    widget.audioHandler
        .customAction('setBandGain', {'band': bandIndex, 'gain': gain});
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fitHeight,
      alignment: Alignment.bottomCenter,
      child: Transform.rotate(
        angle: -pi / 2,
        child: Container(
          width: 400.0,
          height: 400.0,
          alignment: Alignment.center,
          child: Slider(
            activeColor: Theme.of(context).colorScheme.secondary,
            inactiveColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.4),
            value: sliderValue ?? widget.value!,
            min: widget.min!,
            max: widget.max!,
            onChanged: (double newValue) {
              setState(() {
                sliderValue = newValue;
                setGain(widget.bandIndex, newValue);
              });
            },
          ),
        ),
      ),
    );
  }
}
