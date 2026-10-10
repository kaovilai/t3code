import type { ThreadPullRequestLink, VcsStatusResult } from "@t3tools/contracts";
import { resolveThreadCurrentPullRequestLink } from "@t3tools/shared/threadPullRequests";

/**
 * A thread's linked pull request can live on a ref other than the checkout (a fork branch, a
 * stacked layer), so the ref-derived git status misses it and the menus offer Create PR instead
 * of opening the one that exists. Fold the current open link into the status. A link whose
 * first sync has not landed has no snapshot; like the thread list, treat it as open.
 */
export function withLinkedPullRequest(
  gitStatus: VcsStatusResult | null,
  pullRequests: ReadonlyArray<ThreadPullRequestLink> | undefined,
): VcsStatusResult | null {
  if (gitStatus === null || gitStatus.pr?.state === "open") return gitStatus;
  const link = resolveThreadCurrentPullRequestLink(pullRequests ?? []);
  if (link === null) return gitStatus;
  const { snapshot } = link;
  if (snapshot !== null && snapshot.state !== "open") return gitStatus;
  return {
    ...gitStatus,
    pr: {
      number: link.number,
      url: link.url,
      title: snapshot?.title ?? `#${link.number}`,
      baseRef: snapshot?.baseBranch ?? "unknown",
      headRef: snapshot?.headBranch ?? "unknown",
      state: "open",
      ...(snapshot ? { isDraft: snapshot.isDraft, updatedAt: snapshot.updatedAt } : {}),
    },
  };
}
