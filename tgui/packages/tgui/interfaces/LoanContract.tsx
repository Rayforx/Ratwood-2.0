import {
  Button,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
} from 'tgui-core/components';
import { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Clause = {
  path: string;
  name: string;
  desc: string;
  enabled: BooleanLike;
};

type ChastityStyle = {
  key: string;
  label: string;
};

type Data = {
  state: number;
  loaded: number;
  creditor: string;
  surcharge: number;
  rate: number;
  due_days: number;
  punish_forever: BooleanLike;
  brand_text: string;
  chastity_style: string;
  chastity_styles: ChastityStyle[];
  clauses: Clause[];
  repaid_pool: number;
  debtor: string;
  owed: number;
  base_debt: number;
  days_left: number;
  overdue: BooleanLike;
  fired: BooleanLike;
};

const STATE_BLANK = 0;
const STATE_FUNDED = 1;
const STATE_SIGNED = 2;
const STATE_PAID = 3;

export const LoanContract = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    state,
    loaded,
    creditor,
    surcharge,
    rate,
    due_days,
    punish_forever,
    brand_text,
    chastity_style,
    chastity_styles = [],
    clauses = [],
    repaid_pool,
    debtor,
    owed,
    base_debt,
    days_left,
    overdue,
    fired,
  } = data;

  const brandEnabled = clauses.some(
    (clause) => clause.path === '/datum/loan_clause/brand' && clause.enabled,
  );
  const chastityEnabled = clauses.some(
    (clause) => clause.path === '/datum/loan_clause/chastity' && clause.enabled,
  );

  return (
    <Window title="Loan Contract" width={430} height={560}>
      <Window.Content scrollable>
        {state === STATE_BLANK && (
          <NoticeBox>
            This note is not yet backed by any coin. Bind coin to it to offer a
            loan.
          </NoticeBox>
        )}
        {state === STATE_FUNDED && (
          <>
            <Section title="Terms">
              <LabeledList>
                <LabeledList.Item label="Coin offered">
                  {loaded} mammon (by {creditor})
                </LabeledList.Item>
                <LabeledList.Item label="Surcharge">
                  <NumberInput
                    step={1}
                    minValue={0}
                    maxValue={100000}
                    value={surcharge}
                    onChange={(value: number) =>
                      act('set_surcharge', { value })
                    }
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Interest (%/day)">
                  <NumberInput
                    step={1}
                    minValue={0}
                    maxValue={1000}
                    value={rate}
                    onChange={(value: number) => act('set_rate', { value })}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Due in (days)">
                  <NumberInput
                    step={1}
                    minValue={1}
                    maxValue={7}
                    value={due_days}
                    onChange={(value: number) => act('set_due', { value })}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Owed at signing">
                  {loaded + surcharge} mammon
                </LabeledList.Item>
              </LabeledList>
            </Section>
            <Section title="Clauses on default">
              {clauses.map((clause) => (
                <Button.Checkbox
                  key={clause.path}
                  fluid
                  checked={clause.enabled}
                  tooltip={clause.desc}
                  onClick={() => act('toggle_clause', { path: clause.path })}
                >
                  {clause.name}
                </Button.Checkbox>
              ))}
              <Button.Checkbox
                fluid
                mt={1}
                color="bad"
                checked={punish_forever}
                tooltip="The clauses never lift, not even once the debt is repaid."
                onClick={() => act('toggle_forever')}
              >
                Punishments last forever
              </Button.Checkbox>
              {brandEnabled && (
                <LabeledList>
                  <LabeledList.Item label="Brand wording">
                    <Input
                      fluid
                      value={brand_text}
                      placeholder={`${creditor}'s brand is seared into their flesh...`}
                      onBlur={(value: string) =>
                        act('set_brand_text', { value })
                      }
                    />
                  </LabeledList.Item>
                </LabeledList>
              )}
              {chastityEnabled && (
                <LabeledList>
                  <LabeledList.Item label="Chastity device">
                    {chastity_styles.map((style) => (
                      <Button
                        key={style.key}
                        selected={style.key === chastity_style}
                        onClick={() =>
                          act('set_chastity_style', { key: style.key })
                        }
                      >
                        {style.label}
                      </Button>
                    ))}
                  </LabeledList.Item>
                </LabeledList>
              )}
            </Section>
            <NoticeBox info>
              Hand the note to the borrower, who signs it with a feather.
            </NoticeBox>
          </>
        )}
        {(state === STATE_SIGNED || state === STATE_PAID) && (
          <Section
            title={state === STATE_PAID ? 'Settled debt' : 'Standing debt'}
          >
            <LabeledList>
              <LabeledList.Item label="Debtor">{debtor}</LabeledList.Item>
              <LabeledList.Item label="Creditor">{creditor}</LabeledList.Item>
              <LabeledList.Item label="Owed">
                {state === STATE_PAID ? 'PAID IN FULL' : `${owed} mammon`}
              </LabeledList.Item>
              <LabeledList.Item label="Debt began at">
                {base_debt} mammon
                {rate > 0 ? `, growing ${rate}% a day` : ''}
              </LabeledList.Item>
              <LabeledList.Item label="Due">
                {state === STATE_PAID
                  ? 'SETTLED'
                  : overdue
                    ? 'OVERDUE'
                    : `in ${days_left} ${days_left === 1 ? 'day' : 'days'}`}
              </LabeledList.Item>
              {clauses.length > 0 && (
                <LabeledList.Item label="Clauses">
                  {clauses.map((clause) => clause.name).join(', ')}
                  {punish_forever ? ' (forever)' : ' (until repaid)'}
                  {fired ? ' - IN FORCE' : ''}
                </LabeledList.Item>
              )}
              {repaid_pool > 0 && (
                <LabeledList.Item label="Repaid coin held">
                  {repaid_pool} mammon
                </LabeledList.Item>
              )}
            </LabeledList>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
