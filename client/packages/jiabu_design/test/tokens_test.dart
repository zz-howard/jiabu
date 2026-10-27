import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  test('JiabuColors copies and interpolates every field', () {
    const a = JiabuColors();
    final b = a.copyWith(
      bg: a.bg.withValues(alpha: .2),
      paper: a.paper.withValues(alpha: .2),
      surface2: a.surface2.withValues(alpha: .2),
      surface3: a.surface3.withValues(alpha: .2),
      line: a.line.withValues(alpha: .2),
      lineStrong: a.lineStrong.withValues(alpha: .2),
      rule: a.rule.withValues(alpha: .2),
      margin: a.margin.withValues(alpha: .2),
      dot: a.dot.withValues(alpha: .2),
      ink: a.ink.withValues(alpha: .2),
      ink2: a.ink2.withValues(alpha: .2),
      ink3: a.ink3.withValues(alpha: .2),
      primary: a.primary.withValues(alpha: .2),
      primaryText: a.primaryText.withValues(alpha: .2),
      onPrimary: a.onPrimary.withValues(alpha: .2),
      primarySoft: a.primarySoft.withValues(alpha: .2),
      onPrimarySoft: a.onPrimarySoft.withValues(alpha: .2),
      highlight: a.highlight.withValues(alpha: .2),
      note: a.note.withValues(alpha: .2),
      noteInk: a.noteInk.withValues(alpha: .2),
      noteEdge: a.noteEdge.withValues(alpha: .2),
      pos: a.pos.withValues(alpha: .2),
      posSoft: a.posSoft.withValues(alpha: .2),
      neg: a.neg.withValues(alpha: .2),
      warn: a.warn.withValues(alpha: .2),
      warnSoft: a.warnSoft.withValues(alpha: .2),
      alert: a.alert.withValues(alpha: .2),
      alertInk: a.alertInk.withValues(alpha: .2),
      snackBg: a.snackBg.withValues(alpha: .2),
      snackInk: a.snackInk.withValues(alpha: .2),
      snackAction: a.snackAction.withValues(alpha: .2),
      scrim: a.scrim.withValues(alpha: .2),
      chartLeft: a.chartLeft.withValues(alpha: .2),
      chartRight: a.chartRight.withValues(alpha: .2),
      tapeA: a.tapeA.withValues(alpha: .2),
      tapeB: a.tapeB.withValues(alpha: .2),
      tape2: a.tape2.withValues(alpha: .2),
      tape3: a.tape3.withValues(alpha: .2),
      white: a.white.withValues(alpha: .2),
      transparent: a.transparent.withValues(alpha: .2),
      shadowInk: a.shadowInk.withValues(alpha: .2),
      black: a.black.withValues(alpha: .2),
      spaceAccents: {
        for (final e in a.spaceAccents.entries)
          e.key: e.value.withValues(alpha: .2),
      },
      stickerBackgrounds: {
        for (final e in a.stickerBackgrounds.entries)
          e.key: e.value.withValues(alpha: .2),
      },
      stickerInks: {
        for (final e in a.stickerInks.entries)
          e.key: e.value.withValues(alpha: .2),
      },
    );
    final middle = a.lerp(b, .5);
    expect(a.lerp(null, .5), same(a));
    expect(a.copyWith().bg, a.bg);
    expect(a.lerp(b, 0).bg, a.bg);
    expect(a.lerp(b, 1).bg, b.bg);
    expect(middle.bg, Color.lerp(a.bg, b.bg, .5));
    expect(a.copyWith().paper, a.paper);
    expect(a.lerp(b, 0).paper, a.paper);
    expect(a.lerp(b, 1).paper, b.paper);
    expect(middle.paper, Color.lerp(a.paper, b.paper, .5));
    expect(a.copyWith().surface2, a.surface2);
    expect(a.lerp(b, 0).surface2, a.surface2);
    expect(a.lerp(b, 1).surface2, b.surface2);
    expect(middle.surface2, Color.lerp(a.surface2, b.surface2, .5));
    expect(a.copyWith().surface3, a.surface3);
    expect(a.lerp(b, 0).surface3, a.surface3);
    expect(a.lerp(b, 1).surface3, b.surface3);
    expect(middle.surface3, Color.lerp(a.surface3, b.surface3, .5));
    expect(a.copyWith().line, a.line);
    expect(a.lerp(b, 0).line, a.line);
    expect(a.lerp(b, 1).line, b.line);
    expect(middle.line, Color.lerp(a.line, b.line, .5));
    expect(a.copyWith().lineStrong, a.lineStrong);
    expect(a.lerp(b, 0).lineStrong, a.lineStrong);
    expect(a.lerp(b, 1).lineStrong, b.lineStrong);
    expect(middle.lineStrong, Color.lerp(a.lineStrong, b.lineStrong, .5));
    expect(a.copyWith().rule, a.rule);
    expect(a.lerp(b, 0).rule, a.rule);
    expect(a.lerp(b, 1).rule, b.rule);
    expect(middle.rule, Color.lerp(a.rule, b.rule, .5));
    expect(a.copyWith().margin, a.margin);
    expect(a.lerp(b, 0).margin, a.margin);
    expect(a.lerp(b, 1).margin, b.margin);
    expect(middle.margin, Color.lerp(a.margin, b.margin, .5));
    expect(a.copyWith().dot, a.dot);
    expect(a.lerp(b, 0).dot, a.dot);
    expect(a.lerp(b, 1).dot, b.dot);
    expect(middle.dot, Color.lerp(a.dot, b.dot, .5));
    expect(a.copyWith().ink, a.ink);
    expect(a.lerp(b, 0).ink, a.ink);
    expect(a.lerp(b, 1).ink, b.ink);
    expect(middle.ink, Color.lerp(a.ink, b.ink, .5));
    expect(a.copyWith().ink2, a.ink2);
    expect(a.lerp(b, 0).ink2, a.ink2);
    expect(a.lerp(b, 1).ink2, b.ink2);
    expect(middle.ink2, Color.lerp(a.ink2, b.ink2, .5));
    expect(a.copyWith().ink3, a.ink3);
    expect(a.lerp(b, 0).ink3, a.ink3);
    expect(a.lerp(b, 1).ink3, b.ink3);
    expect(middle.ink3, Color.lerp(a.ink3, b.ink3, .5));
    expect(a.copyWith().primary, a.primary);
    expect(a.lerp(b, 0).primary, a.primary);
    expect(a.lerp(b, 1).primary, b.primary);
    expect(middle.primary, Color.lerp(a.primary, b.primary, .5));
    expect(a.copyWith().primaryText, a.primaryText);
    expect(a.lerp(b, 0).primaryText, a.primaryText);
    expect(a.lerp(b, 1).primaryText, b.primaryText);
    expect(middle.primaryText, Color.lerp(a.primaryText, b.primaryText, .5));
    expect(a.copyWith().onPrimary, a.onPrimary);
    expect(a.lerp(b, 0).onPrimary, a.onPrimary);
    expect(a.lerp(b, 1).onPrimary, b.onPrimary);
    expect(middle.onPrimary, Color.lerp(a.onPrimary, b.onPrimary, .5));
    expect(a.copyWith().primarySoft, a.primarySoft);
    expect(a.lerp(b, 0).primarySoft, a.primarySoft);
    expect(a.lerp(b, 1).primarySoft, b.primarySoft);
    expect(middle.primarySoft, Color.lerp(a.primarySoft, b.primarySoft, .5));
    expect(a.copyWith().onPrimarySoft, a.onPrimarySoft);
    expect(a.lerp(b, 0).onPrimarySoft, a.onPrimarySoft);
    expect(a.lerp(b, 1).onPrimarySoft, b.onPrimarySoft);
    expect(
      middle.onPrimarySoft,
      Color.lerp(a.onPrimarySoft, b.onPrimarySoft, .5),
    );
    expect(a.copyWith().highlight, a.highlight);
    expect(a.lerp(b, 0).highlight, a.highlight);
    expect(a.lerp(b, 1).highlight, b.highlight);
    expect(middle.highlight, Color.lerp(a.highlight, b.highlight, .5));
    expect(a.copyWith().note, a.note);
    expect(a.lerp(b, 0).note, a.note);
    expect(a.lerp(b, 1).note, b.note);
    expect(middle.note, Color.lerp(a.note, b.note, .5));
    expect(a.copyWith().noteInk, a.noteInk);
    expect(a.lerp(b, 0).noteInk, a.noteInk);
    expect(a.lerp(b, 1).noteInk, b.noteInk);
    expect(middle.noteInk, Color.lerp(a.noteInk, b.noteInk, .5));
    expect(a.copyWith().noteEdge, a.noteEdge);
    expect(a.lerp(b, 0).noteEdge, a.noteEdge);
    expect(a.lerp(b, 1).noteEdge, b.noteEdge);
    expect(middle.noteEdge, Color.lerp(a.noteEdge, b.noteEdge, .5));
    expect(a.copyWith().pos, a.pos);
    expect(a.lerp(b, 0).pos, a.pos);
    expect(a.lerp(b, 1).pos, b.pos);
    expect(middle.pos, Color.lerp(a.pos, b.pos, .5));
    expect(a.copyWith().posSoft, a.posSoft);
    expect(a.lerp(b, 0).posSoft, a.posSoft);
    expect(a.lerp(b, 1).posSoft, b.posSoft);
    expect(middle.posSoft, Color.lerp(a.posSoft, b.posSoft, .5));
    expect(a.copyWith().neg, a.neg);
    expect(a.lerp(b, 0).neg, a.neg);
    expect(a.lerp(b, 1).neg, b.neg);
    expect(middle.neg, Color.lerp(a.neg, b.neg, .5));
    expect(a.copyWith().warn, a.warn);
    expect(a.lerp(b, 0).warn, a.warn);
    expect(a.lerp(b, 1).warn, b.warn);
    expect(middle.warn, Color.lerp(a.warn, b.warn, .5));
    expect(a.copyWith().warnSoft, a.warnSoft);
    expect(a.lerp(b, 0).warnSoft, a.warnSoft);
    expect(a.lerp(b, 1).warnSoft, b.warnSoft);
    expect(middle.warnSoft, Color.lerp(a.warnSoft, b.warnSoft, .5));
    expect(a.copyWith().alert, a.alert);
    expect(a.lerp(b, 0).alert, a.alert);
    expect(a.lerp(b, 1).alert, b.alert);
    expect(middle.alert, Color.lerp(a.alert, b.alert, .5));
    expect(a.copyWith().alertInk, a.alertInk);
    expect(a.lerp(b, 0).alertInk, a.alertInk);
    expect(a.lerp(b, 1).alertInk, b.alertInk);
    expect(middle.alertInk, Color.lerp(a.alertInk, b.alertInk, .5));
    expect(a.copyWith().snackBg, a.snackBg);
    expect(a.lerp(b, 0).snackBg, a.snackBg);
    expect(a.lerp(b, 1).snackBg, b.snackBg);
    expect(middle.snackBg, Color.lerp(a.snackBg, b.snackBg, .5));
    expect(a.copyWith().snackInk, a.snackInk);
    expect(a.lerp(b, 0).snackInk, a.snackInk);
    expect(a.lerp(b, 1).snackInk, b.snackInk);
    expect(middle.snackInk, Color.lerp(a.snackInk, b.snackInk, .5));
    expect(a.copyWith().snackAction, a.snackAction);
    expect(a.lerp(b, 0).snackAction, a.snackAction);
    expect(a.lerp(b, 1).snackAction, b.snackAction);
    expect(middle.snackAction, Color.lerp(a.snackAction, b.snackAction, .5));
    expect(a.copyWith().scrim, a.scrim);
    expect(a.lerp(b, 0).scrim, a.scrim);
    expect(a.lerp(b, 1).scrim, b.scrim);
    expect(middle.scrim, Color.lerp(a.scrim, b.scrim, .5));
    expect(a.copyWith().chartLeft, a.chartLeft);
    expect(a.lerp(b, 0).chartLeft, a.chartLeft);
    expect(a.lerp(b, 1).chartLeft, b.chartLeft);
    expect(middle.chartLeft, Color.lerp(a.chartLeft, b.chartLeft, .5));
    expect(a.copyWith().chartRight, a.chartRight);
    expect(a.lerp(b, 0).chartRight, a.chartRight);
    expect(a.lerp(b, 1).chartRight, b.chartRight);
    expect(middle.chartRight, Color.lerp(a.chartRight, b.chartRight, .5));
    expect(a.copyWith().tapeA, a.tapeA);
    expect(a.lerp(b, 0).tapeA, a.tapeA);
    expect(a.lerp(b, 1).tapeA, b.tapeA);
    expect(middle.tapeA, Color.lerp(a.tapeA, b.tapeA, .5));
    expect(a.copyWith().tapeB, a.tapeB);
    expect(a.lerp(b, 0).tapeB, a.tapeB);
    expect(a.lerp(b, 1).tapeB, b.tapeB);
    expect(middle.tapeB, Color.lerp(a.tapeB, b.tapeB, .5));
    expect(a.copyWith().tape2, a.tape2);
    expect(a.lerp(b, 0).tape2, a.tape2);
    expect(a.lerp(b, 1).tape2, b.tape2);
    expect(middle.tape2, Color.lerp(a.tape2, b.tape2, .5));
    expect(a.copyWith().tape3, a.tape3);
    expect(a.lerp(b, 0).tape3, a.tape3);
    expect(a.lerp(b, 1).tape3, b.tape3);
    expect(middle.tape3, Color.lerp(a.tape3, b.tape3, .5));
    expect(a.copyWith().white, a.white);
    expect(a.lerp(b, 0).white, a.white);
    expect(a.lerp(b, 1).white, b.white);
    expect(middle.white, Color.lerp(a.white, b.white, .5));
    expect(a.copyWith().transparent, a.transparent);
    expect(a.lerp(b, 0).transparent, a.transparent);
    expect(a.lerp(b, 1).transparent, b.transparent);
    expect(middle.transparent, Color.lerp(a.transparent, b.transparent, .5));
    expect(a.copyWith().shadowInk, a.shadowInk);
    expect(a.lerp(b, 0).shadowInk, a.shadowInk);
    expect(a.lerp(b, 1).shadowInk, b.shadowInk);
    expect(middle.shadowInk, Color.lerp(a.shadowInk, b.shadowInk, .5));
    expect(a.copyWith().black, a.black);
    expect(a.lerp(b, 0).black, a.black);
    expect(a.lerp(b, 1).black, b.black);
    expect(middle.black, Color.lerp(a.black, b.black, .5));
    expect(a.copyWith().spaceAccents, a.spaceAccents);
    expect(a.lerp(b, 0).spaceAccents, a.spaceAccents);
    expect(a.lerp(b, 1).spaceAccents, b.spaceAccents);
    expect(middle.spaceAccents, {
      for (final e in a.spaceAccents.entries)
        e.key: Color.lerp(e.value, b.spaceAccents[e.key], .5),
    });
    expect(a.copyWith().stickerBackgrounds, a.stickerBackgrounds);
    expect(a.lerp(b, 0).stickerBackgrounds, a.stickerBackgrounds);
    expect(a.lerp(b, 1).stickerBackgrounds, b.stickerBackgrounds);
    expect(middle.stickerBackgrounds, {
      for (final e in a.stickerBackgrounds.entries)
        e.key: Color.lerp(e.value, b.stickerBackgrounds[e.key], .5),
    });
    expect(a.copyWith().stickerInks, a.stickerInks);
    expect(a.lerp(b, 0).stickerInks, a.stickerInks);
    expect(a.lerp(b, 1).stickerInks, b.stickerInks);
    expect(middle.stickerInks, {
      for (final e in a.stickerInks.entries)
        e.key: Color.lerp(e.value, b.stickerInks[e.key], .5),
    });
  });

  test('JiabuType copies and interpolates every field', () {
    const a = JiabuType();
    final b = a.copyWith(
      pageTitle: a.pageTitle.copyWith(
        fontSize: (a.pageTitle.fontSize ?? 12) + 2,
      ),
      subtitle: a.subtitle.copyWith(fontSize: (a.subtitle.fontSize ?? 12) + 2),
      englishSubtitle: a.englishSubtitle.copyWith(
        fontSize: (a.englishSubtitle.fontSize ?? 12) + 2,
      ),
      sectionTitle: a.sectionTitle.copyWith(
        fontSize: (a.sectionTitle.fontSize ?? 12) + 2,
      ),
      cardTitle: a.cardTitle.copyWith(
        fontSize: (a.cardTitle.fontSize ?? 12) + 2,
      ),
      question: a.question.copyWith(fontSize: (a.question.fontSize ?? 12) + 2),
      body: a.body.copyWith(fontSize: (a.body.fontSize ?? 12) + 2),
      chat: a.chat.copyWith(fontSize: (a.chat.fontSize ?? 12) + 2),
      listTitle: a.listTitle.copyWith(
        fontSize: (a.listTitle.fontSize ?? 12) + 2,
      ),
      secondary: a.secondary.copyWith(
        fontSize: (a.secondary.fontSize ?? 12) + 2,
      ),
      caption: a.caption.copyWith(fontSize: (a.caption.fontSize ?? 12) + 2),
      badge: a.badge.copyWith(fontSize: (a.badge.fontSize ?? 12) + 2),
      heroAmount: a.heroAmount.copyWith(
        fontSize: (a.heroAmount.fontSize ?? 12) + 2,
      ),
      detailAmount: a.detailAmount.copyWith(
        fontSize: (a.detailAmount.fontSize ?? 12) + 2,
      ),
      recordAmount: a.recordAmount.copyWith(
        fontSize: (a.recordAmount.fontSize ?? 12) + 2,
      ),
      balanceAmount: a.balanceAmount.copyWith(
        fontSize: (a.balanceAmount.fontSize ?? 12) + 2,
      ),
      listAmount: a.listAmount.copyWith(
        fontSize: (a.listAmount.fontSize ?? 12) + 2,
      ),
      inlineAmount: a.inlineAmount.copyWith(
        fontSize: (a.inlineAmount.fontSize ?? 12) + 2,
      ),
      date: a.date.copyWith(fontSize: (a.date.fontSize ?? 12) + 2),
      tapeDate: a.tapeDate.copyWith(fontSize: (a.tapeDate.fontSize ?? 12) + 2),
      mono: a.mono.copyWith(fontSize: (a.mono.fontSize ?? 12) + 2),
    );
    final middle = a.lerp(b, .5);
    expect(a.lerp(null, .5), same(a));
    expect(a.copyWith().pageTitle, a.pageTitle);
    expect(a.lerp(b, 0).pageTitle, a.pageTitle);
    expect(a.lerp(b, 1).pageTitle, b.pageTitle);
    expect(middle.pageTitle, TextStyle.lerp(a.pageTitle, b.pageTitle, .5));
    expect(a.copyWith().subtitle, a.subtitle);
    expect(a.lerp(b, 0).subtitle, a.subtitle);
    expect(a.lerp(b, 1).subtitle, b.subtitle);
    expect(middle.subtitle, TextStyle.lerp(a.subtitle, b.subtitle, .5));
    expect(a.copyWith().englishSubtitle, a.englishSubtitle);
    expect(a.lerp(b, 0).englishSubtitle, a.englishSubtitle);
    expect(a.lerp(b, 1).englishSubtitle, b.englishSubtitle);
    expect(
      middle.englishSubtitle,
      TextStyle.lerp(a.englishSubtitle, b.englishSubtitle, .5),
    );
    expect(a.copyWith().sectionTitle, a.sectionTitle);
    expect(a.lerp(b, 0).sectionTitle, a.sectionTitle);
    expect(a.lerp(b, 1).sectionTitle, b.sectionTitle);
    expect(
      middle.sectionTitle,
      TextStyle.lerp(a.sectionTitle, b.sectionTitle, .5),
    );
    expect(a.copyWith().cardTitle, a.cardTitle);
    expect(a.lerp(b, 0).cardTitle, a.cardTitle);
    expect(a.lerp(b, 1).cardTitle, b.cardTitle);
    expect(middle.cardTitle, TextStyle.lerp(a.cardTitle, b.cardTitle, .5));
    expect(a.copyWith().question, a.question);
    expect(a.lerp(b, 0).question, a.question);
    expect(a.lerp(b, 1).question, b.question);
    expect(middle.question, TextStyle.lerp(a.question, b.question, .5));
    expect(a.copyWith().body, a.body);
    expect(a.lerp(b, 0).body, a.body);
    expect(a.lerp(b, 1).body, b.body);
    expect(middle.body, TextStyle.lerp(a.body, b.body, .5));
    expect(a.copyWith().chat, a.chat);
    expect(a.lerp(b, 0).chat, a.chat);
    expect(a.lerp(b, 1).chat, b.chat);
    expect(middle.chat, TextStyle.lerp(a.chat, b.chat, .5));
    expect(a.copyWith().listTitle, a.listTitle);
    expect(a.lerp(b, 0).listTitle, a.listTitle);
    expect(a.lerp(b, 1).listTitle, b.listTitle);
    expect(middle.listTitle, TextStyle.lerp(a.listTitle, b.listTitle, .5));
    expect(a.copyWith().secondary, a.secondary);
    expect(a.lerp(b, 0).secondary, a.secondary);
    expect(a.lerp(b, 1).secondary, b.secondary);
    expect(middle.secondary, TextStyle.lerp(a.secondary, b.secondary, .5));
    expect(a.copyWith().caption, a.caption);
    expect(a.lerp(b, 0).caption, a.caption);
    expect(a.lerp(b, 1).caption, b.caption);
    expect(middle.caption, TextStyle.lerp(a.caption, b.caption, .5));
    expect(a.copyWith().badge, a.badge);
    expect(a.lerp(b, 0).badge, a.badge);
    expect(a.lerp(b, 1).badge, b.badge);
    expect(middle.badge, TextStyle.lerp(a.badge, b.badge, .5));
    expect(a.copyWith().heroAmount, a.heroAmount);
    expect(a.lerp(b, 0).heroAmount, a.heroAmount);
    expect(a.lerp(b, 1).heroAmount, b.heroAmount);
    expect(middle.heroAmount, TextStyle.lerp(a.heroAmount, b.heroAmount, .5));
    expect(a.copyWith().detailAmount, a.detailAmount);
    expect(a.lerp(b, 0).detailAmount, a.detailAmount);
    expect(a.lerp(b, 1).detailAmount, b.detailAmount);
    expect(
      middle.detailAmount,
      TextStyle.lerp(a.detailAmount, b.detailAmount, .5),
    );
    expect(a.copyWith().recordAmount, a.recordAmount);
    expect(a.lerp(b, 0).recordAmount, a.recordAmount);
    expect(a.lerp(b, 1).recordAmount, b.recordAmount);
    expect(
      middle.recordAmount,
      TextStyle.lerp(a.recordAmount, b.recordAmount, .5),
    );
    expect(a.copyWith().balanceAmount, a.balanceAmount);
    expect(a.lerp(b, 0).balanceAmount, a.balanceAmount);
    expect(a.lerp(b, 1).balanceAmount, b.balanceAmount);
    expect(
      middle.balanceAmount,
      TextStyle.lerp(a.balanceAmount, b.balanceAmount, .5),
    );
    expect(a.copyWith().listAmount, a.listAmount);
    expect(a.lerp(b, 0).listAmount, a.listAmount);
    expect(a.lerp(b, 1).listAmount, b.listAmount);
    expect(middle.listAmount, TextStyle.lerp(a.listAmount, b.listAmount, .5));
    expect(a.copyWith().inlineAmount, a.inlineAmount);
    expect(a.lerp(b, 0).inlineAmount, a.inlineAmount);
    expect(a.lerp(b, 1).inlineAmount, b.inlineAmount);
    expect(
      middle.inlineAmount,
      TextStyle.lerp(a.inlineAmount, b.inlineAmount, .5),
    );
    expect(a.copyWith().date, a.date);
    expect(a.lerp(b, 0).date, a.date);
    expect(a.lerp(b, 1).date, b.date);
    expect(middle.date, TextStyle.lerp(a.date, b.date, .5));
    expect(a.copyWith().tapeDate, a.tapeDate);
    expect(a.lerp(b, 0).tapeDate, a.tapeDate);
    expect(a.lerp(b, 1).tapeDate, b.tapeDate);
    expect(middle.tapeDate, TextStyle.lerp(a.tapeDate, b.tapeDate, .5));
    expect(a.copyWith().mono, a.mono);
    expect(a.lerp(b, 0).mono, a.mono);
    expect(a.lerp(b, 1).mono, b.mono);
    expect(middle.mono, TextStyle.lerp(a.mono, b.mono, .5));
  });

  test('JiabuDecor copies and interpolates every field', () {
    final a = JiabuDecor.paper(const JiabuColors());
    final b = a.copyWith(
      pageInset: a.pageInset + 2,
      narrowHeaderInset: a.narrowHeaderInset + 2,
      compactHeaderInset: a.compactHeaderInset + 2,
      cardInset: a.cardInset + 2,
      recordActionsInset: a.recordActionsInset + 2,
      heroInsetY: a.heroInsetY + 2,
      heroInsetX: a.heroInsetX + 2,
      cardGap: a.cardGap + 2,
      gridGap: a.gridGap + 2,
      sectionTop: a.sectionTop + 2,
      sectionBottom: a.sectionBottom + 2,
      messageGap: a.messageGap + 2,
      aiTop: a.aiTop + 2,
      aiBottom: a.aiBottom + 2,
      rowMinHeight: a.rowMinHeight + 2,
      rowInset: a.rowInset + 2,
      valueRowMinHeight: a.valueRowMinHeight + 2,
      cardRadius: a.cardRadius + 2,
      photoRadius: a.photoRadius + 2,
      noteRadius: a.noteRadius + 2,
      fieldRadius: a.fieldRadius + 2,
      searchRadius: a.searchRadius + 2,
      chipRadius: a.chipRadius + 2,
      sheetRadius: a.sheetRadius + 2,
      snackRadius: a.snackRadius + 2,
      tapeWidth: a.tapeWidth + 2,
      tapeHeight: a.tapeHeight + 2,
      handleWidth: a.handleWidth + 2,
      handleHeight: a.handleHeight + 2,
      stickerSize: a.stickerSize + 2,
      compactStickerSize: a.compactStickerSize + 2,
      stickerBorder: a.stickerBorder + 2,
      stickerStroke: a.stickerStroke + 2,
      stampHeight: a.stampHeight + 2,
      stampBorder: a.stampBorder + 2,
      stampRadius: a.stampRadius + 2,
      stampOpacity: a.stampOpacity + 2,
      photoBorder: a.photoBorder + 2,
      photoBottom: a.photoBottom + 2,
      circleStroke: a.circleStroke + 2,
      strikeStroke: a.strikeStroke + 2,
      dotStep: a.dotStep + 2,
      dotRadius: a.dotRadius + 2,
      marginX: a.marginX + 2,
      tapeTilt: a.tapeTilt + 2,
      stickerTilt: a.stickerTilt + 2,
      stampTilt: a.stampTilt + 2,
      photoTilt: a.photoTilt + 2,
      strikeTilt: a.strikeTilt + 2,
      noteAmp: a.noteAmp + 2,
      heroTilt: a.heroTilt + 2,
      personalTilt: a.personalTilt + 2,
      inputNoteTilt: a.inputNoteTilt + 2,
      answerOddTilt: a.answerOddTilt + 2,
      answerEvenTilt: a.answerEvenTilt + 2,
      logoTilt: a.logoTilt + 2,
      dateTilt: a.dateTilt + 2,
      tapeA: a.tapeA.withValues(alpha: .2),
      tapeB: a.tapeB.withValues(alpha: .2),
      tape2: a.tape2.withValues(alpha: .2),
      tape3: a.tape3.withValues(alpha: .2),
      stickerShadow: a.stickerShadow
          .map((v) => v.copyWith(blurRadius: v.blurRadius + 2))
          .toList(),
      cardShadow: a.cardShadow
          .map((v) => v.copyWith(blurRadius: v.blurRadius + 2))
          .toList(),
      heroShadow: a.heroShadow
          .map((v) => v.copyWith(blurRadius: v.blurRadius + 2))
          .toList(),
      sheetShadow: a.sheetShadow
          .map((v) => v.copyWith(blurRadius: v.blurRadius + 2))
          .toList(),
    );
    final middle = a.lerp(b, .5);
    expect(a.lerp(null, .5), same(a));
    expect(a.copyWith().pageInset, a.pageInset);
    expect(a.lerp(b, 0).pageInset, a.pageInset);
    expect(a.lerp(b, 1).pageInset, b.pageInset);
    expect(middle.pageInset, closeTo(a.pageInset + 1, 1e-9));
    expect(a.copyWith().narrowHeaderInset, a.narrowHeaderInset);
    expect(a.lerp(b, 0).narrowHeaderInset, a.narrowHeaderInset);
    expect(a.lerp(b, 1).narrowHeaderInset, b.narrowHeaderInset);
    expect(middle.narrowHeaderInset, closeTo(a.narrowHeaderInset + 1, 1e-9));
    expect(a.copyWith().compactHeaderInset, a.compactHeaderInset);
    expect(a.lerp(b, 0).compactHeaderInset, a.compactHeaderInset);
    expect(a.lerp(b, 1).compactHeaderInset, b.compactHeaderInset);
    expect(middle.compactHeaderInset, closeTo(a.compactHeaderInset + 1, 1e-9));
    expect(a.copyWith().cardInset, a.cardInset);
    expect(a.lerp(b, 0).cardInset, a.cardInset);
    expect(a.lerp(b, 1).cardInset, b.cardInset);
    expect(middle.cardInset, closeTo(a.cardInset + 1, 1e-9));
    expect(a.copyWith().recordActionsInset, a.recordActionsInset);
    expect(a.lerp(b, 0).recordActionsInset, a.recordActionsInset);
    expect(a.lerp(b, 1).recordActionsInset, b.recordActionsInset);
    expect(middle.recordActionsInset, closeTo(a.recordActionsInset + 1, 1e-9));
    expect(a.copyWith().heroInsetY, a.heroInsetY);
    expect(a.lerp(b, 0).heroInsetY, a.heroInsetY);
    expect(a.lerp(b, 1).heroInsetY, b.heroInsetY);
    expect(middle.heroInsetY, closeTo(a.heroInsetY + 1, 1e-9));
    expect(a.copyWith().heroInsetX, a.heroInsetX);
    expect(a.lerp(b, 0).heroInsetX, a.heroInsetX);
    expect(a.lerp(b, 1).heroInsetX, b.heroInsetX);
    expect(middle.heroInsetX, closeTo(a.heroInsetX + 1, 1e-9));
    expect(a.copyWith().cardGap, a.cardGap);
    expect(a.lerp(b, 0).cardGap, a.cardGap);
    expect(a.lerp(b, 1).cardGap, b.cardGap);
    expect(middle.cardGap, closeTo(a.cardGap + 1, 1e-9));
    expect(a.copyWith().gridGap, a.gridGap);
    expect(a.lerp(b, 0).gridGap, a.gridGap);
    expect(a.lerp(b, 1).gridGap, b.gridGap);
    expect(middle.gridGap, closeTo(a.gridGap + 1, 1e-9));
    expect(a.copyWith().sectionTop, a.sectionTop);
    expect(a.lerp(b, 0).sectionTop, a.sectionTop);
    expect(a.lerp(b, 1).sectionTop, b.sectionTop);
    expect(middle.sectionTop, closeTo(a.sectionTop + 1, 1e-9));
    expect(a.copyWith().sectionBottom, a.sectionBottom);
    expect(a.lerp(b, 0).sectionBottom, a.sectionBottom);
    expect(a.lerp(b, 1).sectionBottom, b.sectionBottom);
    expect(middle.sectionBottom, closeTo(a.sectionBottom + 1, 1e-9));
    expect(a.copyWith().messageGap, a.messageGap);
    expect(a.lerp(b, 0).messageGap, a.messageGap);
    expect(a.lerp(b, 1).messageGap, b.messageGap);
    expect(middle.messageGap, closeTo(a.messageGap + 1, 1e-9));
    expect(a.copyWith().aiTop, a.aiTop);
    expect(a.lerp(b, 0).aiTop, a.aiTop);
    expect(a.lerp(b, 1).aiTop, b.aiTop);
    expect(middle.aiTop, closeTo(a.aiTop + 1, 1e-9));
    expect(a.copyWith().aiBottom, a.aiBottom);
    expect(a.lerp(b, 0).aiBottom, a.aiBottom);
    expect(a.lerp(b, 1).aiBottom, b.aiBottom);
    expect(middle.aiBottom, closeTo(a.aiBottom + 1, 1e-9));
    expect(a.copyWith().rowMinHeight, a.rowMinHeight);
    expect(a.lerp(b, 0).rowMinHeight, a.rowMinHeight);
    expect(a.lerp(b, 1).rowMinHeight, b.rowMinHeight);
    expect(middle.rowMinHeight, closeTo(a.rowMinHeight + 1, 1e-9));
    expect(a.copyWith().rowInset, a.rowInset);
    expect(a.lerp(b, 0).rowInset, a.rowInset);
    expect(a.lerp(b, 1).rowInset, b.rowInset);
    expect(middle.rowInset, closeTo(a.rowInset + 1, 1e-9));
    expect(a.copyWith().valueRowMinHeight, a.valueRowMinHeight);
    expect(a.lerp(b, 0).valueRowMinHeight, a.valueRowMinHeight);
    expect(a.lerp(b, 1).valueRowMinHeight, b.valueRowMinHeight);
    expect(middle.valueRowMinHeight, closeTo(a.valueRowMinHeight + 1, 1e-9));
    expect(a.copyWith().cardRadius, a.cardRadius);
    expect(a.lerp(b, 0).cardRadius, a.cardRadius);
    expect(a.lerp(b, 1).cardRadius, b.cardRadius);
    expect(middle.cardRadius, closeTo(a.cardRadius + 1, 1e-9));
    expect(a.copyWith().photoRadius, a.photoRadius);
    expect(a.lerp(b, 0).photoRadius, a.photoRadius);
    expect(a.lerp(b, 1).photoRadius, b.photoRadius);
    expect(middle.photoRadius, closeTo(a.photoRadius + 1, 1e-9));
    expect(a.copyWith().noteRadius, a.noteRadius);
    expect(a.lerp(b, 0).noteRadius, a.noteRadius);
    expect(a.lerp(b, 1).noteRadius, b.noteRadius);
    expect(middle.noteRadius, closeTo(a.noteRadius + 1, 1e-9));
    expect(a.copyWith().fieldRadius, a.fieldRadius);
    expect(a.lerp(b, 0).fieldRadius, a.fieldRadius);
    expect(a.lerp(b, 1).fieldRadius, b.fieldRadius);
    expect(middle.fieldRadius, closeTo(a.fieldRadius + 1, 1e-9));
    expect(a.copyWith().searchRadius, a.searchRadius);
    expect(a.lerp(b, 0).searchRadius, a.searchRadius);
    expect(a.lerp(b, 1).searchRadius, b.searchRadius);
    expect(middle.searchRadius, closeTo(a.searchRadius + 1, 1e-9));
    expect(a.copyWith().chipRadius, a.chipRadius);
    expect(a.lerp(b, 0).chipRadius, a.chipRadius);
    expect(a.lerp(b, 1).chipRadius, b.chipRadius);
    expect(middle.chipRadius, closeTo(a.chipRadius + 1, 1e-9));
    expect(a.copyWith().sheetRadius, a.sheetRadius);
    expect(a.lerp(b, 0).sheetRadius, a.sheetRadius);
    expect(a.lerp(b, 1).sheetRadius, b.sheetRadius);
    expect(middle.sheetRadius, closeTo(a.sheetRadius + 1, 1e-9));
    expect(a.copyWith().snackRadius, a.snackRadius);
    expect(a.lerp(b, 0).snackRadius, a.snackRadius);
    expect(a.lerp(b, 1).snackRadius, b.snackRadius);
    expect(middle.snackRadius, closeTo(a.snackRadius + 1, 1e-9));
    expect(a.copyWith().tapeWidth, a.tapeWidth);
    expect(a.lerp(b, 0).tapeWidth, a.tapeWidth);
    expect(a.lerp(b, 1).tapeWidth, b.tapeWidth);
    expect(middle.tapeWidth, closeTo(a.tapeWidth + 1, 1e-9));
    expect(a.copyWith().tapeHeight, a.tapeHeight);
    expect(a.lerp(b, 0).tapeHeight, a.tapeHeight);
    expect(a.lerp(b, 1).tapeHeight, b.tapeHeight);
    expect(middle.tapeHeight, closeTo(a.tapeHeight + 1, 1e-9));
    expect(a.copyWith().handleWidth, a.handleWidth);
    expect(a.lerp(b, 0).handleWidth, a.handleWidth);
    expect(a.lerp(b, 1).handleWidth, b.handleWidth);
    expect(middle.handleWidth, closeTo(a.handleWidth + 1, 1e-9));
    expect(a.copyWith().handleHeight, a.handleHeight);
    expect(a.lerp(b, 0).handleHeight, a.handleHeight);
    expect(a.lerp(b, 1).handleHeight, b.handleHeight);
    expect(middle.handleHeight, closeTo(a.handleHeight + 1, 1e-9));
    expect(a.copyWith().stickerSize, a.stickerSize);
    expect(a.lerp(b, 0).stickerSize, a.stickerSize);
    expect(a.lerp(b, 1).stickerSize, b.stickerSize);
    expect(middle.stickerSize, closeTo(a.stickerSize + 1, 1e-9));
    expect(a.copyWith().compactStickerSize, a.compactStickerSize);
    expect(a.lerp(b, 0).compactStickerSize, a.compactStickerSize);
    expect(a.lerp(b, 1).compactStickerSize, b.compactStickerSize);
    expect(middle.compactStickerSize, closeTo(a.compactStickerSize + 1, 1e-9));
    expect(a.copyWith().stickerBorder, a.stickerBorder);
    expect(a.lerp(b, 0).stickerBorder, a.stickerBorder);
    expect(a.lerp(b, 1).stickerBorder, b.stickerBorder);
    expect(middle.stickerBorder, closeTo(a.stickerBorder + 1, 1e-9));
    expect(a.copyWith().stickerStroke, a.stickerStroke);
    expect(a.lerp(b, 0).stickerStroke, a.stickerStroke);
    expect(a.lerp(b, 1).stickerStroke, b.stickerStroke);
    expect(middle.stickerStroke, closeTo(a.stickerStroke + 1, 1e-9));
    expect(a.copyWith().stampHeight, a.stampHeight);
    expect(a.lerp(b, 0).stampHeight, a.stampHeight);
    expect(a.lerp(b, 1).stampHeight, b.stampHeight);
    expect(middle.stampHeight, closeTo(a.stampHeight + 1, 1e-9));
    expect(a.copyWith().stampBorder, a.stampBorder);
    expect(a.lerp(b, 0).stampBorder, a.stampBorder);
    expect(a.lerp(b, 1).stampBorder, b.stampBorder);
    expect(middle.stampBorder, closeTo(a.stampBorder + 1, 1e-9));
    expect(a.copyWith().stampRadius, a.stampRadius);
    expect(a.lerp(b, 0).stampRadius, a.stampRadius);
    expect(a.lerp(b, 1).stampRadius, b.stampRadius);
    expect(middle.stampRadius, closeTo(a.stampRadius + 1, 1e-9));
    expect(a.copyWith().stampOpacity, a.stampOpacity);
    expect(a.lerp(b, 0).stampOpacity, a.stampOpacity);
    expect(a.lerp(b, 1).stampOpacity, b.stampOpacity);
    expect(middle.stampOpacity, closeTo(a.stampOpacity + 1, 1e-9));
    expect(a.copyWith().photoBorder, a.photoBorder);
    expect(a.lerp(b, 0).photoBorder, a.photoBorder);
    expect(a.lerp(b, 1).photoBorder, b.photoBorder);
    expect(middle.photoBorder, closeTo(a.photoBorder + 1, 1e-9));
    expect(a.copyWith().photoBottom, a.photoBottom);
    expect(a.lerp(b, 0).photoBottom, a.photoBottom);
    expect(a.lerp(b, 1).photoBottom, b.photoBottom);
    expect(middle.photoBottom, closeTo(a.photoBottom + 1, 1e-9));
    expect(a.copyWith().circleStroke, a.circleStroke);
    expect(a.lerp(b, 0).circleStroke, a.circleStroke);
    expect(a.lerp(b, 1).circleStroke, b.circleStroke);
    expect(middle.circleStroke, closeTo(a.circleStroke + 1, 1e-9));
    expect(a.copyWith().strikeStroke, a.strikeStroke);
    expect(a.lerp(b, 0).strikeStroke, a.strikeStroke);
    expect(a.lerp(b, 1).strikeStroke, b.strikeStroke);
    expect(middle.strikeStroke, closeTo(a.strikeStroke + 1, 1e-9));
    expect(a.copyWith().dotStep, a.dotStep);
    expect(a.lerp(b, 0).dotStep, a.dotStep);
    expect(a.lerp(b, 1).dotStep, b.dotStep);
    expect(middle.dotStep, closeTo(a.dotStep + 1, 1e-9));
    expect(a.copyWith().dotRadius, a.dotRadius);
    expect(a.lerp(b, 0).dotRadius, a.dotRadius);
    expect(a.lerp(b, 1).dotRadius, b.dotRadius);
    expect(middle.dotRadius, closeTo(a.dotRadius + 1, 1e-9));
    expect(a.copyWith().marginX, a.marginX);
    expect(a.lerp(b, 0).marginX, a.marginX);
    expect(a.lerp(b, 1).marginX, b.marginX);
    expect(middle.marginX, closeTo(a.marginX + 1, 1e-9));
    expect(a.copyWith().tapeTilt, a.tapeTilt);
    expect(a.lerp(b, 0).tapeTilt, a.tapeTilt);
    expect(a.lerp(b, 1).tapeTilt, b.tapeTilt);
    expect(middle.tapeTilt, closeTo(a.tapeTilt + 1, 1e-9));
    expect(a.copyWith().stickerTilt, a.stickerTilt);
    expect(a.lerp(b, 0).stickerTilt, a.stickerTilt);
    expect(a.lerp(b, 1).stickerTilt, b.stickerTilt);
    expect(middle.stickerTilt, closeTo(a.stickerTilt + 1, 1e-9));
    expect(a.copyWith().stampTilt, a.stampTilt);
    expect(a.lerp(b, 0).stampTilt, a.stampTilt);
    expect(a.lerp(b, 1).stampTilt, b.stampTilt);
    expect(middle.stampTilt, closeTo(a.stampTilt + 1, 1e-9));
    expect(a.copyWith().photoTilt, a.photoTilt);
    expect(a.lerp(b, 0).photoTilt, a.photoTilt);
    expect(a.lerp(b, 1).photoTilt, b.photoTilt);
    expect(middle.photoTilt, closeTo(a.photoTilt + 1, 1e-9));
    expect(a.copyWith().strikeTilt, a.strikeTilt);
    expect(a.lerp(b, 0).strikeTilt, a.strikeTilt);
    expect(a.lerp(b, 1).strikeTilt, b.strikeTilt);
    expect(middle.strikeTilt, closeTo(a.strikeTilt + 1, 1e-9));
    expect(a.copyWith().noteAmp, a.noteAmp);
    expect(a.lerp(b, 0).noteAmp, a.noteAmp);
    expect(a.lerp(b, 1).noteAmp, b.noteAmp);
    expect(middle.noteAmp, closeTo(a.noteAmp + 1, 1e-9));
    expect(a.copyWith().heroTilt, a.heroTilt);
    expect(a.lerp(b, 0).heroTilt, a.heroTilt);
    expect(a.lerp(b, 1).heroTilt, b.heroTilt);
    expect(middle.heroTilt, closeTo(a.heroTilt + 1, 1e-9));
    expect(a.copyWith().personalTilt, a.personalTilt);
    expect(a.lerp(b, 0).personalTilt, a.personalTilt);
    expect(a.lerp(b, 1).personalTilt, b.personalTilt);
    expect(middle.personalTilt, closeTo(a.personalTilt + 1, 1e-9));
    expect(a.copyWith().inputNoteTilt, a.inputNoteTilt);
    expect(a.lerp(b, 0).inputNoteTilt, a.inputNoteTilt);
    expect(a.lerp(b, 1).inputNoteTilt, b.inputNoteTilt);
    expect(middle.inputNoteTilt, closeTo(a.inputNoteTilt + 1, 1e-9));
    expect(a.copyWith().answerOddTilt, a.answerOddTilt);
    expect(a.lerp(b, 0).answerOddTilt, a.answerOddTilt);
    expect(a.lerp(b, 1).answerOddTilt, b.answerOddTilt);
    expect(middle.answerOddTilt, closeTo(a.answerOddTilt + 1, 1e-9));
    expect(a.copyWith().answerEvenTilt, a.answerEvenTilt);
    expect(a.lerp(b, 0).answerEvenTilt, a.answerEvenTilt);
    expect(a.lerp(b, 1).answerEvenTilt, b.answerEvenTilt);
    expect(middle.answerEvenTilt, closeTo(a.answerEvenTilt + 1, 1e-9));
    expect(a.copyWith().logoTilt, a.logoTilt);
    expect(a.lerp(b, 0).logoTilt, a.logoTilt);
    expect(a.lerp(b, 1).logoTilt, b.logoTilt);
    expect(middle.logoTilt, closeTo(a.logoTilt + 1, 1e-9));
    expect(a.copyWith().dateTilt, a.dateTilt);
    expect(a.lerp(b, 0).dateTilt, a.dateTilt);
    expect(a.lerp(b, 1).dateTilt, b.dateTilt);
    expect(middle.dateTilt, closeTo(a.dateTilt + 1, 1e-9));
    expect(a.copyWith().tapeA, a.tapeA);
    expect(a.lerp(b, 0).tapeA, a.tapeA);
    expect(a.lerp(b, 1).tapeA, b.tapeA);
    expect(middle.tapeA, Color.lerp(a.tapeA, b.tapeA, .5));
    expect(a.copyWith().tapeB, a.tapeB);
    expect(a.lerp(b, 0).tapeB, a.tapeB);
    expect(a.lerp(b, 1).tapeB, b.tapeB);
    expect(middle.tapeB, Color.lerp(a.tapeB, b.tapeB, .5));
    expect(a.copyWith().tape2, a.tape2);
    expect(a.lerp(b, 0).tape2, a.tape2);
    expect(a.lerp(b, 1).tape2, b.tape2);
    expect(middle.tape2, Color.lerp(a.tape2, b.tape2, .5));
    expect(a.copyWith().tape3, a.tape3);
    expect(a.lerp(b, 0).tape3, a.tape3);
    expect(a.lerp(b, 1).tape3, b.tape3);
    expect(middle.tape3, Color.lerp(a.tape3, b.tape3, .5));
    expect(a.copyWith().stickerShadow, a.stickerShadow);
    expect(a.lerp(b, 0).stickerShadow, a.stickerShadow);
    expect(a.lerp(b, 1).stickerShadow, b.stickerShadow);
    expect(
      middle.stickerShadow,
      BoxShadow.lerpList(a.stickerShadow, b.stickerShadow, .5),
    );
    expect(a.copyWith().cardShadow, a.cardShadow);
    expect(a.lerp(b, 0).cardShadow, a.cardShadow);
    expect(a.lerp(b, 1).cardShadow, b.cardShadow);
    expect(
      middle.cardShadow,
      BoxShadow.lerpList(a.cardShadow, b.cardShadow, .5),
    );
    expect(a.copyWith().heroShadow, a.heroShadow);
    expect(a.lerp(b, 0).heroShadow, a.heroShadow);
    expect(a.lerp(b, 1).heroShadow, b.heroShadow);
    expect(
      middle.heroShadow,
      BoxShadow.lerpList(a.heroShadow, b.heroShadow, .5),
    );
    expect(a.copyWith().sheetShadow, a.sheetShadow);
    expect(a.lerp(b, 0).sheetShadow, a.sheetShadow);
    expect(a.lerp(b, 1).sheetShadow, b.sheetShadow);
    expect(
      middle.sheetShadow,
      BoxShadow.lerpList(a.sheetShadow, b.sheetShadow, .5),
    );
  });

  test('JiabuMotion copies and interpolates every field', () {
    const a = JiabuMotion();
    final b = a.copyWith(
      sheet: a.sheet + const Duration(milliseconds: 200),
      scrim: a.scrim + const Duration(milliseconds: 200),
      snack: a.snack + const Duration(milliseconds: 200),
      space: a.space + const Duration(milliseconds: 200),
      send: a.send + const Duration(milliseconds: 200),
      cardIn: a.cardIn + const Duration(milliseconds: 200),
      typing: a.typing + const Duration(milliseconds: 200),
      processing: a.processing + const Duration(milliseconds: 200),
      sheetCurve: Curves.linear,
      transitionCurve: Curves.linear,
    );
    final middle = a.lerp(b, .5);
    expect(a.lerp(null, .5), same(a));
    expect(a.copyWith().sheet, a.sheet);
    expect(a.lerp(b, 0).sheet, a.sheet);
    expect(a.lerp(b, 1).sheet, b.sheet);
    expect(middle.sheet, a.sheet + const Duration(milliseconds: 100));
    expect(a.copyWith().scrim, a.scrim);
    expect(a.lerp(b, 0).scrim, a.scrim);
    expect(a.lerp(b, 1).scrim, b.scrim);
    expect(middle.scrim, a.scrim + const Duration(milliseconds: 100));
    expect(a.copyWith().snack, a.snack);
    expect(a.lerp(b, 0).snack, a.snack);
    expect(a.lerp(b, 1).snack, b.snack);
    expect(middle.snack, a.snack + const Duration(milliseconds: 100));
    expect(a.copyWith().space, a.space);
    expect(a.lerp(b, 0).space, a.space);
    expect(a.lerp(b, 1).space, b.space);
    expect(middle.space, a.space + const Duration(milliseconds: 100));
    expect(a.copyWith().send, a.send);
    expect(a.lerp(b, 0).send, a.send);
    expect(a.lerp(b, 1).send, b.send);
    expect(middle.send, a.send + const Duration(milliseconds: 100));
    expect(a.copyWith().cardIn, a.cardIn);
    expect(a.lerp(b, 0).cardIn, a.cardIn);
    expect(a.lerp(b, 1).cardIn, b.cardIn);
    expect(middle.cardIn, a.cardIn + const Duration(milliseconds: 100));
    expect(a.copyWith().typing, a.typing);
    expect(a.lerp(b, 0).typing, a.typing);
    expect(a.lerp(b, 1).typing, b.typing);
    expect(middle.typing, a.typing + const Duration(milliseconds: 100));
    expect(a.copyWith().processing, a.processing);
    expect(a.lerp(b, 0).processing, a.processing);
    expect(a.lerp(b, 1).processing, b.processing);
    expect(middle.processing, a.processing + const Duration(milliseconds: 100));
    expect(a.copyWith().sheetCurve, a.sheetCurve);
    expect(a.lerp(b, 0).sheetCurve, a.sheetCurve);
    expect(a.lerp(b, 1).sheetCurve, b.sheetCurve);
    expect(middle.sheetCurve, b.sheetCurve);
    expect(a.copyWith().transitionCurve, a.transitionCurve);
    expect(a.lerp(b, 0).transitionCurve, a.transitionCurve);
    expect(a.lerp(b, 1).transitionCurve, b.transitionCurve);
    expect(middle.transitionCurve, b.transitionCurve);
  });

  test('paper shadow levels retain their exact layers', () {
    final d = JiabuDecor.paper(const JiabuColors());
    expect(d.stickerShadow, hasLength(2));
    expect(d.cardShadow, hasLength(2));
    expect(d.heroShadow, hasLength(2));
    expect(d.sheetShadow, hasLength(1));
    expect(d.stickerShadow.last.spreadRadius, -4);
    expect(d.cardShadow.last.offset, const Offset(0, 12));
    expect(d.heroShadow.last.blurRadius, 26);
    expect(d.sheetShadow.single.offset, const Offset(0, -8));
  });

  testWidgets('all motion durations vanish under disableAnimations', (
    tester,
  ) async {
    JiabuMotion? motion;
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              motion = context.jiabu.motion;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect([
      motion!.sheet,
      motion!.scrim,
      motion!.snack,
      motion!.space,
      motion!.send,
      motion!.cardIn,
      motion!.typing,
      motion!.processing,
    ], everyElement(Duration.zero));
    expect(const JiabuDecor().stickerTilt, -6);
  });
}
