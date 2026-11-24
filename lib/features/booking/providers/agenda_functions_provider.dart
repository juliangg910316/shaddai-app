import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/agenda_functions.dart';

/// Las funciones del servidor que escriben en la agenda (spec 012, plan
/// D-1): reservar, editar y guardar un cierre. Los tests la sustituyen por
/// `FakeAgendaFunctions`.
final agendaFunctionsProvider = Provider<AgendaFunctions>(
  (ref) => AgendaFunctions(),
);
